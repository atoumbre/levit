// Reactive state store using Svelte 5 runes
import type { ReactiveItem, ServerMessage } from '../types';
import { onMessage } from './websocket.svelte';

// Export reactive state object directly
export const reactiveState = $state<{
    state: Map<string, ReactiveItem>;
    history: Map<string, ReactiveItem[]>;
    updateCounts: Map<string, number>;
}>({
    state: new Map(),
    history: new Map(),
    updateCounts: new Map()
});

// Initialize message handler
onMessage((message: ServerMessage) => {
    switch (message.type) {
        case 'init':
            reactiveState.state = new Map();
            reactiveState.history = new Map();
            reactiveState.updateCounts = new Map();
            (message.reactive || []).forEach((item) => {
                if (item.id) {
                    reactiveState.state.set(item.id, item);
                }
            });
            break;

        case 'event':
            if (message.data?.category === 'state') {
                const data = message.data;
                const id = data.id as string | undefined;
                // State events use 'type' field from Dart, not 'event'
                const event = (data.type || data.event) as string | undefined;

                if (id) {
                    // Handle flags_updated - merge new flags without counting as update
                    if (event === 'flags_updated') {
                        const newState = new Map(reactiveState.state);
                        const existing = newState.get(id);
                        if (existing) {
                            // Merge flags and metadata
                            const existingFlags = existing.flags || {};
                            const newFlags = (data.flags || {}) as Record<string, unknown>;
                            newState.set(id, {
                                ...existing,
                                name: (data.name as string) || existing.name,
                                flags: { ...existingFlags, ...newFlags }
                            });
                            reactiveState.state = newState;
                        }
                        break;
                    }

                    // Track history for init/update - create new Map for reactivity
                    const newHistory = new Map(reactiveState.history);
                    const historyList = [...(newHistory.get(id) || [])];
                    historyList.unshift(data as unknown as ReactiveItem);
                    if (historyList.length > 50) historyList.pop();
                    newHistory.set(id, historyList);
                    reactiveState.history = newHistory;

                    // Update count
                    const newCounts = new Map(reactiveState.updateCounts);
                    newCounts.set(id, (newCounts.get(id) || 0) + 1);
                    reactiveState.updateCounts = newCounts;

                    // Update state
                    const newState = new Map(reactiveState.state);
                    if (event === 'init' || event === 'update' || event === 'register') {
                        const existing = newState.get(id) || {} as ReactiveItem;
                        newState.set(id, { ...existing, ...(data as unknown as ReactiveItem) });
                    } else if (event === 'dispose') {
                        newState.delete(id);
                    }
                    reactiveState.state = newState;
                }
            }
            break;
    }
});
