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
            console.log('[RegistryStore] init message received', message);
            registryState.apps = message.apps || [];
            registryState.registry = new Map();
            const initAppId = message.appId || (registryState.apps.length > 0 ? registryState.apps[0].id : 'unknown');

            (message.registry || []).forEach((item) => {
                const appId = item.appId || initAppId;
                const fullKey = `${appId}:${item.scopeId}:${item.key}`;
                registryState.registry.set(fullKey, { ...item, appId, fullKey });
            });
            console.log(`[RegistryStore] Initialized with ${registryState.registry.size} items for ${registryState.apps.length} apps`);
            // Auto-select first app if available
            if (registryState.apps.length > 0 && !registryState.selectedAppId) {
                registryState.selectedAppId = registryState.apps[0].id;
                console.log(`[RegistryStore] Auto-selected app: ${registryState.selectedAppId}`);
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
            if (message.data) {
                const data = message.data;
                const eventType = data.type || (data as any).event;
                const appId = message.appId || 'unknown';

                if (eventType === 'di_register' || eventType === 'register') {
                    const fullKey = `${appId}:${data.scopeId}:${data.key}`;
                    console.log(`[RegistryStore] register event: ${data.key}`, data);

                    // Create new Map to trigger reactivity
                    const newRegistry = new Map(registryState.registry);
                    const item = {
                        ...data,
                        scope: data.scopeName || (data as any).scope || 'Unknown',
                        type: typeof data.key === 'string' && data.key.includes(':')
                            ? data.key.split(':')[1]
                            : (data as any).className || 'dependency',
                        appId,
                        fullKey
                    } as unknown as RegistryItem;
                    newRegistry.set(fullKey, item);
                    registryState.registry = newRegistry;
                    console.log(`[RegistryStore] Registry updated: ${newRegistry.size} items`);
                } else if (eventType === 'di_delete' || eventType === 'delete') {
                    const fullKey = `${appId}:${data.scopeId}:${data.key}`;
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
    reactiveStateMap: Map<string, unknown>,
    appId: string
): unknown[] {
    const linked: unknown[] = [];
    const registryScopeId = String(scopeId);

    reactiveStateMap.forEach((item: any) => {
        // Must match application ID
        if (item.appId !== appId) return;

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
