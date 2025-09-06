import { getEthConsensusProofBundleEntity } from '../golemConsensusProofEntity.js';
import { GolemWrappedClient } from '../golemClient.js';

async function main() {
    const golemClient = new GolemWrappedClient();
    await golemClient.init();
    const bundle = await getEthConsensusProofBundleEntity(
        golemClient.client,
        30
    );
    console.log('Got bundle', bundle);
}

main()
    .then(() => {
        console.log('retrieved bundle 1');
        process.exit(0);
    })
    .catch((e) => {
        const error = e as Error;
        console.error(error?.stack ?? error?.message ?? String(error));
        process.exit(1);
    });
