use golem_base_sdk::{
    entity::{Create, EntityResult},
    Annotation, GolemBaseClient,
};
use serde::{Deserialize, Serialize};
use std::time::Duration;

// Define record block time to live
const ETH_CONSENSUS_PROOF_TTL: u64 = 24 * 60 * 60;
const ETH_CONSENSUS_PROOF_BTL: u64 = (ETH_CONSENSUS_PROOF_TTL as f64 / 2.0).ceil() as u64;

/// Your proof bundle type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EthConsensusProofBundleAndWindow {
    pub input_block_number: u64,
    pub output_block_number: u64,
    // add the rest of the fields you need here
}

/// Serialise the proof bundle into bytes
pub fn serialise_eth_consensus_proof_bundle(
    proof_bundle: &EthConsensusProofBundleAndWindow,
) -> Vec<u8> {
    serde_json::to_vec(proof_bundle).expect("Failed to serialise proof bundle")
}

/// Deserialise the proof bundle from bytes
pub fn deserialise_eth_consensus_proof_bundle(
    data: &[u8],
) -> EthConsensusProofBundleAndWindow {
    let decoded = std::str::from_utf8(data).expect("Invalid UTF-8 in stored proof bundle");
    println!("decoded: {}", decoded);
    serde_json::from_str(decoded).expect("Failed to parse proof bundle JSON")
}

/// Create an entity in golem with the proof bundle
pub async fn create_eth_consensus_proof_bundle_entity(
    client: &GolemBaseClient,
    proof_bundle: EthConsensusProofBundleAndWindow,
) -> anyhow::Result<Vec<EntityResult>> {
    let id = format!(
        "{}_{}",
        proof_bundle.input_block_number, proof_bundle.output_block_number
    );
    let serialised_data = serialise_eth_consensus_proof_bundle(&proof_bundle);
    println!("serialisedData.byteLength = {}", serialised_data.len());

    let create_proof_entity = Create {
        data: serialised_data,
        btl: ETH_CONSENSUS_PROOF_BTL,
        string_annotations: vec![Annotation::new("id", id)],
        numeric_annotations: vec![
            Annotation::new("inputBlockNumber", proof_bundle.input_block_number),
            Annotation::new("outputBlockNumber", proof_bundle.output_block_number),
        ],
    };

    let receipts = client.create_entities(vec![create_proof_entity]).await?;
    Ok(receipts)
}

/// Fetch a proof bundle entity that matches a target block number
pub async fn get_eth_consensus_proof_bundle_entity(
    client: &GolemBaseClient,
    target_block_number: u64,
) -> anyhow::Result<Option<EthConsensusProofBundleAndWindow>> {
    // (inputBlockNumber <= targetBlockNumber) && (outputBlockNumber >= targetBlockNumber)
    let query = format!(
        "(inputBlockNumber < {} || inputBlockNumber = {}) && (outputBlockNumber > {} || outputBlockNumber = {})",
        target_block_number, target_block_number, target_block_number, target_block_number
    );

    let entities = client.query_entities(&query).await?;
    if entities.is_empty() {
        return Ok(None);
    }
    println!("entities.length = {}", entities.len());
    println!("Found entities = {:?}", entities);

    let bundle = deserialise_eth_consensus_proof_bundle(&entities[0].storage_value);
    Ok(Some(bundle))
}
