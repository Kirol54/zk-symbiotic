import { TransitionNoticeMessageType } from '@nori-zk/pts-types';
import { getEthConsensusTransitionProofBundle } from './ethConsensusProofBundleFetcher.js';
import { bridgeStateTopic$ } from './noriBridgeListener.js';
import { filter, mergeMap, map, from } from 'rxjs';

/**
 * Function waits for nori infrastructure proof conversion events, fetches the proof data and returns the proofs and window boundary.
 * @returns An observable with the proof bundle input and output block number
 */
export function proofBundleOnGeneration$() {
    return bridgeStateTopic$.pipe(
        filter(
            ({ stage_name }) =>
                stage_name ===
                TransitionNoticeMessageType.ProofConversionJobSucceeded
        ),
        mergeMap(({ input_block_number, output_block_number }) =>
            from(getEthConsensusTransitionProofBundle(input_block_number)).pipe(
                map((ethConsensusProofBundle) => ({
                    ethConsensusProofBundle,
                    inputBlockNumber: input_block_number,
                    outputBlockNumber: output_block_number,
                }))
            )
        )
    );
}


