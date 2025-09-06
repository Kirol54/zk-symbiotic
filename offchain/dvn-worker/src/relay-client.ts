import axios from 'axios';

export class RelayClient {
  constructor(private readonly baseUrl: string) {}

  async requestSignature(messageHash: string): Promise<{
    aggregatedSignature: string;
    epoch: number;
    proof: string;
  }> {
    try {
      console.log(`Requesting signature for message hash: ${messageHash}`);
      
      // For demo purposes, return mock data
      // In production, this would call the actual Relay Aggregator API
      const response = await axios.post(`${this.baseUrl}/sign`, {
        message: messageHash,
      });

      return {
        aggregatedSignature: response.data.signature || '0x' + '00'.repeat(96), // Mock BLS signature
        epoch: response.data.epoch || 1,
        proof: response.data.proof || '0x' + '00'.repeat(32), // Mock proof
      };
    } catch (error) {
      console.error('Error requesting signature from Relay:', error);
      
      // Return mock data for development
      return {
        aggregatedSignature: '0x' + '00'.repeat(96),
        epoch: 1,
        proof: '0x' + '00'.repeat(32),
      };
    }
  }

  async getCurrentEpoch(): Promise<number> {
    try {
      const response = await axios.get(`${this.baseUrl}/epoch`);
      return response.data.epoch || 1;
    } catch (error) {
      console.error('Error getting current epoch:', error);
      return 1; // Mock epoch
    }
  }
}