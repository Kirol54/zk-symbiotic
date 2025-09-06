import { Annotation, GolemBaseClient, GolemBaseCreate } from 'golem-base-sdk';
import { EthConsensusProofBundleAndWindow } from './types.js';

// Define record block time to live
const ethConsensusProofTTL = 24 * 60 * 60;
const ethConsensusProofBTL = Math.ceil(ethConsensusProofTTL / 2.0);

const encoder = new TextEncoder();
const decoder = new TextDecoder();

export function serialiseEthConsensusProofBundle(
    proofBundle: EthConsensusProofBundleAndWindow
) {
    const str = JSON.stringify(proofBundle);
    //console.log('str.length', str.length);

    //const reduced_str = str.slice(Math.ceil(str.length/2));
    //console.log('reduced_str.length', reduced_str.length);
    const encoded = encoder.encode(str);

    return encoded;
}

export function deserialiseEthConsensusProofBundle(
    proofBundleUint8Array: Uint8Array
) {
    const decoded = decoder.decode(proofBundleUint8Array);
    console.log('decoded', decoded);
    return JSON.parse(
        decoded
    ) as EthConsensusProofBundleAndWindow;
}

export function createEthConsensusProofBundleEntity(
    golemClient: GolemBaseClient,
    proofBundle: EthConsensusProofBundleAndWindow
) {
    const { inputBlockNumber, outputBlockNumber } = proofBundle;
    const id = `${inputBlockNumber}_${outputBlockNumber}`;
    const serialisedData = serialiseEthConsensusProofBundle(proofBundle);
    console.log('serialisedData.byteLength', serialisedData.byteLength);
    const createProofEntity: GolemBaseCreate = {
        data: serialisedData,
        btl: ethConsensusProofBTL,
        stringAnnotations: [new Annotation('id', id)],
        numericAnnotations: [
            new Annotation('inputBlockNumber', inputBlockNumber),
            new Annotation('outputBlockNumber', outputBlockNumber),
        ],
    };
    return golemClient.createEntities([createProofEntity]);
}

export async function getEthConsensusProofBundleEntity(
    golemClient: GolemBaseClient,
    targetBlockNumber: number
) {
    // We want: inputBlockNumber <= targetBlockNumber <= outputBlockNumber
    // Since <= and >= aren't supported, break it into:
    // (inputBlockNumber < targetBlockNumber || inputBlockNumber = targetBlockNumber)
    // AND
    // (outputBlockNumber > targetBlockNumber || outputBlockNumber = targetBlockNumber)

    const entities = await golemClient.queryEntities(
        `(inputBlockNumber < ${targetBlockNumber} || inputBlockNumber = ${targetBlockNumber}) && (outputBlockNumber > ${targetBlockNumber} || outputBlockNumber = ${targetBlockNumber})`
    );
    if (entities.length === 0) return null;
    console.log('entities.length', entities.length);
    console.log('Found entitites', entities);
    return deserialiseEthConsensusProofBundle(entities[0].storageValue);
}
