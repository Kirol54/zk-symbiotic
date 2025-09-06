import axios from "axios";
import { ZkInputs } from "./types";

export class ZkClient {
	constructor(private readonly golemDbUrl?: string) {}

	async getZkProof(packetId: string): Promise<{
		proof: string;
		inputs: ZkInputs;
	}> {
		try {
			if (!this.golemDbUrl) {
				console.log("No GolemDB URL provided, returning stub proof");
				return this.getStubProof();
			}

			console.log(`Fetching ZK proof for packet: ${packetId}`);

			const response = await axios.get(`${this.golemDbUrl}/proof/${packetId}`); // here add other typescirpt code for getting zkProof

			return {
				proof: response.data.proof,
				inputs: response.data.inputs,
			};
		} catch (error) {
			console.error("Error fetching ZK proof:", error);
			console.log("Falling back to stub proof");
			return this.getStubProof();
		}
	}

	private getStubProof(): {
		proof: string;
		inputs: ZkInputs;
	} {
		return {
			proof: "0x" + "00".repeat(128), // Stub proof
			inputs: {
				slot: BigInt(1000), // Stub slot
				blockHash: "0x" + "00".repeat(32),
				receiptsRoot: "0x" + "00".repeat(32),
				emitter: "0x" + "00".repeat(20),
				topicsHash: "0x" + "00".repeat(32),
				logIndex: 0,
				minFinality: BigInt(64), // ~14 minutes
			},
		};
	}
}
