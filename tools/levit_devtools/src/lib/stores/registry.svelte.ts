// Registry state store using Svelte 5 runes
import type { AppInfo, RegistryItem, ServerMessage } from '../types';
import { onMessage } from './websocket.svelte';

// Export reactive state objects directly
export const registryState = $state<{
    apps: AppInfo[];
    registry: Map<string, RegistryItem>;
    selectedAppId: string | null;
}>({
    apps: [],
    registry: new Map(),
    selectedAppId: null
});

// Initialize message handler
onMessage((message: ServerMessage) => {
    switch (message.type) {
        case 'init':
            registryState.apps = message.apps || [];
            registryState.registry = new Map();
            (message.registry || []).forEach((item) => {
                const fullKey = `${item.scopeId}:${item.key}`;
                registryState.registry.set(fullKey, { ...item, fullKey });
            });
            // Auto-select first app if available
            if (registryState.apps.length > 0 && !registryState.selectedAppId) {
                registryState.selectedAppId = registryState.apps[0].id;
            }
            break;

        case 'app_connected':
            registryState.apps = [
                ...registryState.apps,
                {
                    id: message.appId!,
                    name: message.appName!,
                    connectedAt: message.connectedAt!
                }
            ];
            // Auto-select if it's the first one
            if (!registryState.selectedAppId) {
                registryState.selectedAppId = message.appId!;
            }
            break;

        case 'app_disconnected':
            registryState.apps = registryState.apps.filter((a) => a.id !== message.appId);
            break;

        case 'event':
            if (message.data?.category === 'di') {
                const data = message.data;
                const fullKey = `${data.scopeId}:${data.key}`;

                if (data.event === 'register') {
                    // Create new Map to trigger reactivity
                    const newRegistry = new Map(registryState.registry);
                    newRegistry.set(fullKey, { ...data, fullKey } as unknown as RegistryItem);
                    registryState.registry = newRegistry;
                } else if (data.event === 'delete') {
                    const newRegistry = new Map(registryState.registry);
                    newRegistry.delete(fullKey);
                    registryState.registry = newRegistry;
                }
            }
            break;
    }
});

// Helper function to get reactive state by controller
export function getReactiveByController(
    controllerType: string,
    scopeId: number,
    reactiveState: Map<string, unknown>
): unknown[] {
    const linked: unknown[] = [];
    const registryScopeId = String(scopeId);

    reactiveState.forEach((item: any) => {
        const controller = item.ownerId || item.flags?.controller;
        const itemScopeId = item.scopeId || item.flags?.scopeId;

        if (controller === controllerType) {
            if (scopeId > 0) {
                // Scoped: exact match on scopeId
                if (String(itemScopeId) === registryScopeId) {
                    linked.push(item);
                }
            } else {
                // Global scope (scopeId === 0): match items with null/0/undefined scopeId
                if (!itemScopeId || String(itemScopeId) === '0') {
                    linked.push(item);
                }
            }
        }
    });

    return linked;
}

