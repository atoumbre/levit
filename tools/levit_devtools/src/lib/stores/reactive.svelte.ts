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
            const initAppId = message.appId || 'unknown';
            (message.reactive || []).forEach((item) => {
                if (item.id) {
                    const fullId = `${initAppId}:${item.id}`;
                    reactiveState.state.set(fullId, { ...item, appId: initAppId, fullId });
                }
            });
            break;

        case 'event':
            if (message.data) {
                const data = message.data;
                const type = data.type || (data as any).event;
                const appId = message.appId || 'unknown';

                // Handle Batch Events
                if (type === 'batch' && data.entries) {
                    const newState = new Map(reactiveState.state);
                    const newHistory = new Map(reactiveState.history);
                    const newCounts = new Map(reactiveState.updateCounts);

                    data.entries.forEach((entry: any) => {
                        const id = entry.reactiveId;
                        const fullId = `${appId}:${id}`;

                        // Parse composite ownerId if available
                        let scopeId: string | number | undefined = entry.scopeId;
                        if (!scopeId && entry.ownerId && typeof entry.ownerId === 'string' && entry.ownerId.includes(':')) {
                            scopeId = entry.ownerId.split(':')[0];
                        }

                        // Update History
                        const historyList = [...(newHistory.get(fullId) || [])];
                        historyList.unshift({
                            ...entry,
                            timestamp: data.timestamp,
                            type: 'state_change',
                            appId,
                            scopeId: String(scopeId || '0')
                        } as unknown as ReactiveItem);
                        if (historyList.length > 50) historyList.pop();
                        newHistory.set(fullId, historyList);

                        // Update Counts
                        newCounts.set(fullId, (newCounts.get(fullId) || 0) + 1);

                        // Update State
                        const existing = newState.get(fullId) || {} as ReactiveItem;
                        newState.set(fullId, {
                            ...existing,
                            ...entry,
                            id,
                            appId,
                            scopeId: String(scopeId || existing.scopeId || '0'),
                            timestamp: data.timestamp
                        });
                    });

                    reactiveState.state = newState;
                    reactiveState.history = newHistory;
                    reactiveState.updateCounts = newCounts;
                    break;
                }

                const id = (data.reactiveId as string) || (data.id as string);
                if (id) {
                    const fullId = `${appId}:${id}`;
                    const eventType = data.type || (data as any).event;

                    // Handle flags_updated - merge new flags without counting as update
                    if (eventType === 'flags_updated') {
                        const newState = new Map(reactiveState.state);
                        const existing = newState.get(fullId);
                        if (existing) {
                            const newFlags = (data.flags || {}) as Record<string, unknown>;
                            newState.set(fullId, {
                                ...existing,
                                name: (data.name as string) || existing.name,
                                flags: { ...(existing.flags || {}), ...newFlags }
                            });
                            reactiveState.state = newState;
                        }
                        break;
                    }

                    // Track history and update count
                    // DEDUPLICATION: Only add history and increment count for actual updates or FIRST init
                    const isInit = eventType === 'reactive_init' || eventType === 'init' || eventType === 'register';
                    const isUpdate = eventType === 'state_change' || eventType === 'update';

                    const newState = new Map(reactiveState.state);
                    const existing = newState.get(fullId);

                    if (isUpdate || (isInit && !existing)) {
                        const newHistory = new Map(reactiveState.history);
                        const historyList = [...(newHistory.get(fullId) || [])];
                        historyList.unshift({
                            ...data,
                            appId,
                            id // Ensure we have the short ID in history
                        } as unknown as ReactiveItem);
                        if (historyList.length > 50) historyList.pop();
                        newHistory.set(fullId, historyList);
                        reactiveState.history = newHistory;

                        // Update count
                        const newCounts = new Map(reactiveState.updateCounts);
                        newCounts.set(fullId, (newCounts.get(fullId) || 0) + 1);
                        reactiveState.updateCounts = newCounts;
                    }

                    // Update state
                    let scopeId: string | number | undefined = data.scopeId;
                    if (!scopeId && data.ownerId && typeof data.ownerId === 'string' && data.ownerId.includes(':')) {
                        scopeId = data.ownerId.split(':')[0];
                    }

                    if (isInit || isUpdate) {
                        const base = existing || {} as ReactiveItem;
                        newState.set(fullId, {
                            ...base,
                            ...(data as unknown as ReactiveItem),
                            id,
                            appId,
                            scopeId: String(scopeId || base.scopeId || '0')
                        });
                    } else if (eventType === 'graph_change' || eventType === 'dependencies_updated') {
                        if (existing) {
                            newState.set(fullId, {
                                ...existing,
                                dependencies: (data.dependencies as any[])?.map(d => typeof d === 'string' ? d : d.id)
                            });
                        }
                    } else if (eventType === 'reactive_dispose' || eventType === 'dispose') {
                        newState.delete(fullId);
                    }
                    reactiveState.state = newState;
                }
            }
            break;
    }
});
