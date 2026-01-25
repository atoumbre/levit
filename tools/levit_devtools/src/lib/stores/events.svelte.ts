// Events log store using Svelte 5 runes
import type { EventItem, ServerMessage } from '../types';
import { onMessage } from './websocket.svelte';

const MAX_EVENTS = 500;

// Export reactive state object directly
export const eventsState = $state<{ events: EventItem[] }>({ events: [] });

export function clearEvents(): void {
    eventsState.events = [];
}

// Initialize message handler
onMessage((message: ServerMessage) => {
    switch (message.type) {
        case 'init':
            eventsState.events = [];
            break;

        case 'event':
            if (message.data) {
                eventsState.events = [message.data, ...eventsState.events.slice(0, MAX_EVENTS - 1)];
            }
            break;
    }
});
