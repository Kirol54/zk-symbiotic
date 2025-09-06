import 'dotenv/config';
import { config } from 'dotenv';
import {
    createClient,
    AccountData,
    Tagged,
    GolemBaseCreate,
    Annotation,
    GolemBaseUpdate,
    GolemBaseClient,
} from 'golem-base-sdk';

const golemDBEnvVars = {
    privateKeyHex: 'GOLEM_DB_PRIVATE_KEY_HEX',
    rpcUrl: 'GOLEM_DB_RPC_URL',
    wsUrl: 'GOLEM_DB_WS_URL',
    chainId: 'GOLEM_DB_CHAIN_ID',
};

function validateEnv() {
    try {
        const env = config();
        const parsed = env.parsed;
        if (!parsed) throw new Error('Failed to parse environment file.');
        const errors: string[] = [];
        const outputMap: { [key in keyof typeof golemDBEnvVars]: string } =
            {} as any;

        for (const outputMapKey in golemDBEnvVars) {
            const envName =
                golemDBEnvVars[outputMapKey as keyof typeof golemDBEnvVars];

            if (!parsed.hasOwnProperty(envName)) {
                errors.push(`Missing env var for golem client: '${envName}'`);
            }
            outputMap[outputMapKey as keyof typeof golemDBEnvVars] =
                parsed[envName];
        }
        if (errors.length) {
            throw new Error(
                `Error parsing env for golemdb.\n ${errors.join(', ')}`
            );
        }
        return outputMap;
    } catch (e) {
        const error = e as Error;
        console.error(error.stack);
        process.exit(1);
    }
}

export class GolemWrappedClient {
    #key: AccountData;
    #rpcUrl: string;
    #wsUrl: string;
    #chainId: number;
    #inited = false;
    client: GolemBaseClient;

    constructor() {
        const config = validateEnv();
        this.#key = new Tagged(
            'privatekey',
            Buffer.from(config.privateKeyHex, 'hex')
        );
        // should validate these todo.
        this.#rpcUrl = config.rpcUrl;
        this.#wsUrl = config.wsUrl;
        // parse chain id
        const chainId = parseInt(config.chainId);
        if (isNaN(chainId))
            throw new Error(
                `Could not parse chainId as an integer: ${config.chainId}`
            );
        this.#chainId = chainId;
    }

    async init() {
        if (this.#inited === true) return;
        try {
            this.#inited = true;
            const client = await createClient(
                this.#chainId,
                this.#key,
                this.#rpcUrl,
                this.#wsUrl
            );
            this.client = client;
        } catch (e) {
            this.#inited = false;
        }
    }
}
