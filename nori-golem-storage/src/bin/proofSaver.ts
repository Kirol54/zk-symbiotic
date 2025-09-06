import { proofBundleOnGeneration$ } from '../proofObtainer.js';
import { createEthConsensusProofBundleEntity } from '../golemConsensusProofEntity.js';
import { GolemWrappedClient } from '../golemClient.js';
import { mergeMap } from 'rxjs';

export async function main() {
    // Init golem wrapped client
    const golemClient = new GolemWrappedClient();
    await golemClient.init();

    // For every proof generated create an eth consensus golem entity
    proofBundleOnGeneration$()
        .pipe(
            mergeMap(
                ({
                    ethConsensusProofBundle,
                    inputBlockNumber,
                    outputBlockNumber,
                }) => {
                    console.log(
                        `Saving a proof bundle for inputBlockNumber: '${inputBlockNumber}', outputBlockNumber: ${outputBlockNumber}`
                    );
                    return createEthConsensusProofBundleEntity(
                        golemClient.client,
                        {
                            ethConsensusProofBundle,
                            inputBlockNumber,
                            outputBlockNumber,
                        }
                    );
                }
            )
        )
        .subscribe({
            next: () => {
                console.log('Created a record');
            },
            error: (err) => {
                console.error('An error occured', err);
                process.exit(1);
            },
            complete: () => {
                console.log('Golem proof saver completed.');
                process.exit(0);
            },
        });
}

main().catch((e) => {
    const error = e as Error;
    console.error(error?.stack ?? error?.message ?? String(error));
    process.exit(1);
});
