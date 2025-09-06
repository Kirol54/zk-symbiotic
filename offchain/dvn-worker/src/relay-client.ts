import axios from 'axios';

export class RelayClient {
  constructor(private readonly baseUrl: string) {}

  async requestSignature(messageHash: string): Promise<{
    aggregatedSignature: string;
    epoch: number;
    proof: string;
  }> {
    try {
      console.log(`🔐 Requesting signature for message hash: ${messageHash}`);
      console.log(`📡 Contacting Relay Aggregator at: ${this.baseUrl}`);
      
      // Try to call the real Relay Aggregator API
      // The actual API endpoints depend on the Relay implementation
      const response = await axios.post(`${this.baseUrl}/api/v1/aggregate`, {
        message: messageHash,
        timeout: 30000, // 30 second timeout for BLS aggregation
      }, {
        timeout: 35000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (response.data && response.data.signature) {
        console.log(`✅ Got real signature from Relay for epoch: ${response.data.epoch}`);
        return {
          aggregatedSignature: response.data.signature,
          epoch: response.data.epoch,
          proof: response.data.proof || '0x',
        };
      } else {
        throw new Error('Invalid response format from Relay Aggregator');
      }
      
    } catch (error: any) {
      console.warn('⚠️  Could not get signature from Relay Aggregator:', error?.message || error);
      console.log('🔄 Falling back to development mode with mock signatures');
      
      // For Phase 0, return mock data when Relay is not fully running
      // In production, this should fail hard
      return {
        aggregatedSignature: '0x' + '00'.repeat(96), // 96-byte mock BLS signature
        epoch: 1,
        proof: '0x', // Empty proof for Simple BLS verifier
      };
    }
  }

  async getCurrentEpoch(): Promise<number> {
    try {
      const response = await axios.get(`${this.baseUrl}/api/v1/status`, {
        timeout: 5000,
      });
      
      if (response.data && typeof response.data.currentEpoch === 'number') {
        return response.data.currentEpoch;
      }
      
      return 1; // Default epoch
    } catch (error: any) {
      console.warn('⚠️  Could not get current epoch from Relay:', error?.message || error);
      return 1; // Mock epoch
    }
  }

  async checkAggregatorStatus(): Promise<boolean> {
    try {
      const response = await axios.get(`${this.baseUrl}/health`, {
        timeout: 3000,
      });
      
      return response.status === 200;
    } catch (error) {
      console.log(`❌ Aggregator at ${this.baseUrl} is not responding`);
      return false;
    }
  }
}