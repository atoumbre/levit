// Dependency graph store using Svelte 5 runes
import type { ServerMessage } from '../types';
import { onMessage } from './websocket.svelte';
import { registryState } from './registry.svelte';

export interface GraphEdge {
    source: string;  // Computed ID
    target: string;  // Dependency ID
}

// Export reactive state directly for Svelte 5 reactivity
export const graphState = $state<{
    edges: GraphEdge[];
    nodeNames: Map<string, string>;        // id -> name
    nodeTypes: Map<string, string>;        // id -> valueType
    nodeControllers: Map<string, string>;  // id -> controllerId
    nodeScopes: Map<string, string>;       // id -> scopeId (for unique grouping)
    computedIds: Set<string>;              // IDs of computed nodes
}>({
    edges: [],
    nodeNames: new Map(),
    nodeTypes: new Map(),
    nodeControllers: new Map(),
    nodeScopes: new Map(),
    computedIds: new Set()
});

// Get unique controller groups (composite key)
export function getControllerGroups(): { id: string, name: string, scope: string }[] {
    const groups = new Map<string, { id: string, name: string, scope: string }>();

    // Add "all" option
    groups.set('all', { id: 'all', name: 'All Controllers', scope: '' });

    graphState.nodeControllers.forEach((name, nodeId) => {
        if (!name) return;

        // Filter by selected App
        const appId = nodeId.includes(':') ? nodeId.split(':')[0] : null;
        if (appId && registryState.selectedAppId && appId !== registryState.selectedAppId) {
            return;
        }

        const scope = graphState.nodeScopes.get(nodeId) || 'global';
        const uniqueId = `${name}::${scope}`;
        if (!groups.has(uniqueId)) {
            groups.set(uniqueId, { id: uniqueId, name, scope });
        }
    });

    return Array.from(groups.values()).sort((a, b) => a.name.localeCompare(b.name));
}

// Initialize message handler
onMessage((message: ServerMessage) => {
    // Handle app disconnect - clear graph
    if (message.type === 'app_disconnected') {
        const appId = message.appId!;
        // Remove all nodes belonging to this app
        graphState.edges = graphState.edges.filter(e => !e.source.startsWith(`${appId}:`));

        const removeKeys = (map: Map<string, any>) => {
            for (const key of map.keys()) {
                if (key.startsWith(`${appId}:`)) map.delete(key);
            }
            return new Map(map);
        };

        graphState.nodeNames = removeKeys(graphState.nodeNames);
        graphState.nodeTypes = removeKeys(graphState.nodeTypes);
        graphState.nodeControllers = removeKeys(graphState.nodeControllers);
        graphState.nodeScopes = removeKeys(graphState.nodeScopes);

        const newComputed = new Set(graphState.computedIds);
        for (const id of newComputed) {
            if (id.startsWith(`${appId}:`)) newComputed.delete(id);
        }
        graphState.computedIds = newComputed;
        return;
    }

    // Handle full initialization
    if (message.type === 'init') {
        // Only clear if we don't have multiple apps or if we want a full reset?
        // Ideally 'init' is per connection. If we have multiple connections, we might need merging.
        // But usually 'init' comes once per socket connection.
        // For now, let's assuming single connection or we accept clearing.
        // Actually, better to just clear for the specific App if logic allows, but 'init' usually means "Here is everything".

        // Let's reset everything for safety as 'init' is the source of truth for the connection.
        graphState.edges = [];
        graphState.nodeNames = new Map();
        graphState.nodeTypes = new Map();
        graphState.nodeControllers = new Map();
        graphState.nodeScopes = new Map();
        graphState.computedIds = new Set();

        const initAppId = message.appId || 'unknown';

        // Populate from message.reactive
        (message.reactive || []).forEach(item => {
            const rawId = item.id;
            if (!rawId) return;
            const fullId = `${initAppId}:${rawId}`;

            graphState.nodeNames.set(fullId, item.name || rawId);
            graphState.nodeTypes.set(fullId, (item.valueType as string) || 'unknown');
            if (item.ownerId) graphState.nodeControllers.set(fullId, item.ownerId);
            if (item.scopeId) graphState.nodeScopes.set(fullId, String(item.scopeId));

            // Dependencies
            if (item.dependencies && Array.isArray(item.dependencies)) {
                graphState.computedIds.add(fullId);
                const newEdges = (item.dependencies as any[]).map(d => {
                    const depRawId = typeof d === 'string' ? d : d.id;
                    return {
                        source: fullId,
                        target: `${initAppId}:${depRawId}`
                    };
                });
                graphState.edges.push(...newEdges);
            }
        });
        return;
    }


    if (message.type === 'event' && message.data) {
        const data = message.data;
        const type = data.type || (data as any).event;
        const appId = message.appId || 'unknown';

        if (type === 'dependencies_updated') {
            const { id, name, dependencies, valueType, ownerId, scopeId } = data;
            if (id && dependencies && Array.isArray(dependencies)) {
                const fullId = `${appId}:${id}`;

                // Remove old edges for this computed
                graphState.edges = graphState.edges.filter(e => e.source !== fullId);

                // Add new edges
                const newEdges = (dependencies as any[]).map(d => {
                    const depRawId = typeof d === 'string' ? d : d.id;
                    return {
                        source: fullId,
                        target: `${appId}:${depRawId}` // Assume dependencies are in same app
                    };
                });
                graphState.edges = [...graphState.edges, ...newEdges];

                // Update metadata
                if (name) graphState.nodeNames.set(fullId, name);
                graphState.nodeTypes.set(fullId, (valueType as string) || 'unknown');
                if (ownerId) graphState.nodeControllers.set(fullId, ownerId);
                if (scopeId) graphState.nodeScopes.set(fullId, String(scopeId));

                // Mark as computed
                graphState.computedIds.add(fullId);
            }
        }
        else if (type === 'init' && data.id) {
            const fullId = `${appId}:${data.id}`;
            graphState.nodeNames.set(fullId, (data.name || data.id) as string);
            graphState.nodeTypes.set(fullId, (data.valueType as string) || 'unknown');
            if (data.ownerId) graphState.nodeControllers.set(fullId, data.ownerId as string);
            if (data.scopeId) graphState.nodeScopes.set(fullId, String(data.scopeId));
        }
        else if (type === 'dispose' && data.id) {
            const fullId = `${appId}:${data.id}`;
            graphState.edges = graphState.edges.filter(e => e.source !== fullId && e.target !== fullId);
            graphState.nodeNames.delete(fullId);
            graphState.nodeTypes.delete(fullId);
            graphState.nodeControllers.delete(fullId);
            graphState.nodeScopes.delete(fullId);
            graphState.computedIds.delete(fullId);
        }
    }
});
