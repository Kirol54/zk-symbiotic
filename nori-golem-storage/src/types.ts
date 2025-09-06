import { Sp1ProofAndConvertedProofBundle } from '@nori-zk/pts-types';

export interface EthConsensusProofBundleAndWindow {
    ethConsensusProofBundle: Sp1ProofAndConvertedProofBundle;
    inputBlockNumber: number;
    outputBlockNumber: number;
}
