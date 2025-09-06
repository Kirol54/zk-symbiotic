use crate::api::finality_change_detector::FinalityChangeDetectorUpdate;
use crate::api::sp1_prover::{finality_update_job, ProverJobOutput};
use crate::{
    api::finality_change_detector::start_validated_consensus_finality_change_detector,
    rpcs::consensus::ConsensusHttpProxy,
};
use alloy_primitives::FixedBytes;
use anyhow::{Error, Result};
use golem_symbiotic_consensus_mpt_types::types::{
    DualProofInputsWithWindow, ProofInputsWithWindow, ProofOutputs, VerifiedContractStorageSlot,
};
use helios_consensus_core::consensus_spec::MainnetConsensusSpec;
use helios_ethereum::rpc::http_rpc::HttpRpc;
use log::{debug, error, info};
use serde::{Deserialize, Serialize};
use sp1_sdk::SP1ProofWithPublicValues;
use std::collections::HashMap;
use std::error::Error as StdError;
use std::{fmt, process};
use tokio::sync::broadcast;
use tokio::sync::mpsc;
use tokio::time::Instant;

/// Proof types

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct ProofMessage {
    pub input_slot: u64,
    pub input_block_number: u64,
    pub input_store_hash: FixedBytes<32>,
    pub output_slot: u64,
    pub output_block_number: u64,
    pub output_store_hash: FixedBytes<32>,
    pub proof: SP1ProofWithPublicValues,
    pub execution_state_root: FixedBytes<32>,
    pub contract_storage_slots: Vec<VerifiedContractStorageSlot>,
    pub elapsed_sec: f64,
}

struct ProverJob {
    inputs_with_window: ProofInputsWithWindow<MainnetConsensusSpec>,
    start_instant: Instant,
}

pub struct ProverJobError {
    pub job_id: u64,
    pub error: Error,
}

// Implement Display trait for user-friendly error messages
impl fmt::Display for ProverJobError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Prover job {} failed: {}", self.job_id, self.error)
    }
}

// Implement Debug for ProverJobError
impl fmt::Debug for ProverJobError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "ProverJobError {{ job_id: {}, source: {:?} }}",
            self.job_id, self.error
        )
    }
}

// Implement std::error::Error for ProverJobError
impl StdError for ProverJobError {
    fn source(&self) -> Option<&(dyn StdError + 'static)> {
        Some(&*self.error)
    }
}

pub struct EventLoop {
    /// Current finalized slot head
    current_slot: u64,

    finality_output_rx: Option<mpsc::Receiver<DualProofInputsWithWindow<MainnetConsensusSpec>>>,
    finality_advance_input_tx: Option<mpsc::Sender<FinalityChangeDetectorUpdate>>,
    finality_stage_input_tx: Option<mpsc::Sender<FinalityChangeDetectorUpdate>>,
    job_id: u64,
    prover_jobs: HashMap<u64, ProverJob>,
    job_rx: Option<mpsc::UnboundedReceiver<Result<ProverJobOutput, ProverJobError>>>,
    job_tx: mpsc::UnboundedSender<Result<ProverJobOutput, ProverJobError>>,
    /// FixedBytes representing the store hash
    store_hash: FixedBytes<32>,
}

impl EventLoop {
    pub async fn new() -> (EventLoop) {
        // Setup polling client for finality change detection
        let (current_slot, store_hash) =
            ConsensusHttpProxy::<MainnetConsensusSpec, HttpRpc>::try_from_env()
                .get_latest_finality_slot_and_store_hash()
                .await
                .unwrap();

        info!("Starting helios polling client.");
        let (
            init_latest_beacon_slot,
            finality_output_rx,
            finality_advance_input_tx,
            finality_stage_input_tx,
        ) = start_validated_consensus_finality_change_detector::<MainnetConsensusSpec, HttpRpc>(
            current_slot,
            store_hash,
            None, // FIXME this needs to come from persistant state aka from the checkpoint file
        )
        .await;

        // Create job mpsc
        let (job_tx, job_rx) = mpsc::unbounded_channel();

        EventLoop {
            current_slot,
            finality_output_rx: Some(finality_output_rx),
            finality_advance_input_tx: Some(finality_advance_input_tx),
            finality_stage_input_tx: Some(finality_stage_input_tx),
            job_id: 0,
            prover_jobs: HashMap::new(),
            job_rx: Some(job_rx),
            job_tx,
            store_hash,
        }
    }

    // Handle prover job success
    async fn handle_prover_success(
        &mut self,
        job_id: u64,
        proof: SP1ProofWithPublicValues,
    ) -> Result<()> {
        info!("Handling prover job output '{}'.", job_id);

        // Extract jobs details are remove job
        let (inputs_with_window, elapsed_sec) = {
            let job = self.prover_jobs.get(&job_id).unwrap();
            let inputs_with_window = job.inputs_with_window.clone();

            let elapsed_sec = Instant::now()
                .duration_since(job.start_instant)
                .as_secs_f64();

            self.prover_jobs.remove(&job_id);

            (inputs_with_window, elapsed_sec)
        };

        info!("Job '{}' finished in {} seconds.", job_id, elapsed_sec);

        // Extract values out of the proof output
        let public_values: sp1_sdk::SP1PublicValues = proof.clone().public_values;
        let public_values_bytes = public_values.as_slice(); // Raw bytes

        let proof_outputs = ProofOutputs::from_bytes(public_values_bytes)?;
        let input_slot = proof_outputs.input_slot;
        let input_store_hash = proof_outputs.input_store_hash;
        let output_slot = proof_outputs.output_slot;
        let output_store_hash = proof_outputs.output_store_hash;

        info!(
            "...proof_outputs.next_sync_committee_hash {}",
            proof_outputs.next_sync_committee_hash
        );

        info!(
            "PROOF OUTPUT SERIALIZED:\n{}",
            serde_json::to_string(&proof_outputs)?
        );
        info!("-----------------------------------------------------------------------------------------");
        info!("-----------------------------------------------------------------------------------------");
        info!("-----------------------------------------------------------------------------------------");

        // Build a vector of VerifiedContractStorageSlot
        let contract_storage_slots: Vec<VerifiedContractStorageSlot> = inputs_with_window
            .proof_inputs
            .contract_storage
            .storage_slots
            .iter()
            .map(|slot| VerifiedContractStorageSlot {
                slot_key_address: slot.slot_key_address,
                value: slot.expected_value,
            })
            .collect();

        Ok(())
    }

    // Handle prover job failures
    async fn handle_prover_failure(&mut self, err: &ProverJobError) {
        // Extract job details and remove job
        let (inputs_with_window, n_jobs, elapsed_sec) = {
            let job = self.prover_jobs.get(&err.job_id).unwrap();
            let inputs_with_window = job.inputs_with_window.clone();

            let elapsed_sec = Instant::now()
                .duration_since(job.start_instant)
                .as_secs_f64();

            self.prover_jobs.remove(&err.job_id);

            (inputs_with_window, self.prover_jobs.len(), elapsed_sec)
        };

        // Build job failure error message
        let message = format!("Job '{}' failed with error: {}", err.job_id, err);
        error!("{}", message);
    }

    async fn stage_transition_proof(
        &mut self,
        proof_inputs_with_window: ProofInputsWithWindow<MainnetConsensusSpec>,
    ) {
        // Get job id
        self.job_id += 1;
        let job_id: u64 = self.job_id;

        // Print received job message
        info!(
            "Nori bridge head updater received a new job {}. Spawning a new worker.",
            job_id
        );

        // Insert job details into map
        self.prover_jobs.insert(
            job_id,
            ProverJob {
                inputs_with_window: proof_inputs_with_window.clone(),
                start_instant: Instant::now(),
            },
        );

        // Create job data tx
        let tx = self.job_tx.clone();

        // Clone job arguments
        let current_slot = self.current_slot;
        let store_hash = self.store_hash;
        let inputs = proof_inputs_with_window.proof_inputs;
        let expected_output_slot = proof_inputs_with_window.expected_output_slot;
        let expected_output_store_hash = proof_inputs_with_window.expected_output_store_hash;

        // Spawn proof job in worker thread (check for blocking)
        tokio::spawn(async move {
            // Execute job
            let proof_result = finality_update_job(job_id, current_slot, inputs).await;

            // Send appropriate tx Ok or Err
            match proof_result {
                Ok(prover_job_output) => {
                    tx.send(Ok(prover_job_output)).unwrap();
                }
                Err(error) => {
                    let job_error = ProverJobError { job_id, error };
                    tx.send(Err(job_error)).unwrap();
                }
            }
        });

        // Here we should tell the finality_change_detector that we have a job inflight and its expected_output_slot
        // So it can begin preparing proof inputs from this input slot as well..
        // Borrow the transmitter
        if let Some(finality_stage_input_tx) = &self.finality_stage_input_tx {
            let _ = finality_stage_input_tx
                .send(FinalityChangeDetectorUpdate {
                    slot: expected_output_slot,
                    store_hash: expected_output_store_hash,
                })
                .await;
        }
    }

    pub async fn run(mut self) {
        let mut finality_output_rx = self.finality_output_rx.take().unwrap();
        let finality_advance_input_tx = self.finality_advance_input_tx.take().unwrap();
        let mut job_rx = self.job_rx.take().unwrap();

        loop {
            tokio::select! {
                // Read the finality reciever for finality change events
                Some(event) = finality_output_rx.recv() => {
                    // here we need to handle the finality jobs and spawn prover jobs
                },

                // Read the job receiver for returned jobs
                Some(job_result) = job_rx.recv() => {
                    match job_result {
                        Ok(result_data) => {
                            let handle_prover_success_result = self.handle_prover_success(
                                result_data.job_id(),
                                result_data.proof(),
                            ).await;
                            if let Err(err) = handle_prover_success_result {
                                error!("Error handlng prover success: {:?}", err);
                                process::exit(1);
                            }
                        }
                        Err(err) => {
                            let _ = self.handle_prover_failure(&err).await; // Perhaps kill the program
                        }
                    }
                }

            }
        }
    }
}
