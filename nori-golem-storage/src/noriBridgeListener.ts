import { getReconnectingBridgeSocket$ } from '@nori-zk/mina-token-bridge/rx/socket';
import { getBridgeStateTopic$ } from '@nori-zk/mina-token-bridge/rx/topics';
import { shareReplay } from 'rxjs';

// Connect to nori eth state bridge infrastructure and get a hot observable for the bridge state.

const { bridgeSocket$, bridgeSocketConnectionState$ } =
    getReconnectingBridgeSocket$();

bridgeSocketConnectionState$.subscribe({
    next: (state) => console.log(`[NoriBridgeWebsocket] ${state}`),
    error: (state) => console.error(`[NoriBridgeWebsocket] ${state}`),
    complete: () =>
        console.log(
            '[NoriBridgeWebsocket] Bridge socket connection completed.'
        ),
});

const bridgeStateTopic$ = getBridgeStateTopic$(bridgeSocket$).pipe(
    shareReplay(1)
);
bridgeStateTopic$.subscribe();

export { bridgeStateTopic$ };
