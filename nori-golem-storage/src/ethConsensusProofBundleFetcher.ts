import { Sp1ProofAndConvertedProofBundle } from '@nori-zk/pts-types';

/**
 * Get getProofBundle retrieves an sp1 eth consensus finality transition proof (from say finalized slot a and at some later time finalized slot b)
 * and a o1js compatible proof from nori infrastructure. The trouble with these proofs are they exist on a single point of failure node which generates them.
 * We can use the simple rest api provided to get these proofs such that we can commit them somewhere on chain.
 * @param blockNumber
 * @param queryUrl
 */
export async function getEthConsensusTransitionProofBundle(
    blockNumber: number,
    queryUrl = 'https://pcs.nori.it.com/converted-consensus-mpt-proofs'
) {
    const proofBundleResponse = await fetch(`${queryUrl}/${blockNumber}`);
    const jsonResponse = await proofBundleResponse.json();
    if ('error' in jsonResponse) throw new Error(jsonResponse.error as string);
    return jsonResponse as Sp1ProofAndConvertedProofBundle;
}

