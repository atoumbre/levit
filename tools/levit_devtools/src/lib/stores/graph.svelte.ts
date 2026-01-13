// Dependency graph store using Svelte 5 runes
import type { ServerMessage } from '../types';
import { onMessage } from './websocket.svelte';

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
    // Handle dependency graph updates
    if (message.data?.event === 'dependencies_updated') {
        const { id, name, dependencies, valueType, ownerId, scopeId } = message.data;
        if (id && dependencies && Array.isArray(dependencies)) {
            // Remove old edges for this computed
            graphState.edges = graphState.edges.filter(e => e.source !== id);

            // Add new edges
            const newEdges = (dependencies as string[]).map(depId => ({
                source: id as string,
                target: depId
            }));
            graphState.edges = [...graphState.edges, ...newEdges];

            // Update name mapping
            if (name) {
                const newNames = new Map(graphState.nodeNames);
                newNames.set(id as string, name as string);
                graphState.nodeNames = newNames;
            }

            // Update type mapping
            const newTypes = new Map(graphState.nodeTypes);
            newTypes.set(id as string, (valueType as string) || 'unknown');
            graphState.nodeTypes = newTypes;

            // Update controller mapping
            if (ownerId) {
                const newControllers = new Map(graphState.nodeControllers);
                newControllers.set(id as string, ownerId as string);
                graphState.nodeControllers = newControllers;
            }

            // Update scope mapping
            if (scopeId) {
                const newScopes = new Map(graphState.nodeScopes);
                newScopes.set(id as string, String(scopeId));
                graphState.nodeScopes = newScopes;
            }

            // Mark as computed
            const newComputedIds = new Set(graphState.computedIds);
            newComputedIds.add(id as string);
            graphState.computedIds = newComputedIds;
        }
    }

    // Capture names, types, and controllers from init events
    if (message.data?.event === 'init' && message.data.id) {
        const id = message.data.id as string;

        const newNames = new Map(graphState.nodeNames);
        newNames.set(id, (message.data.name || id) as string);
        graphState.nodeNames = newNames;

        const newTypes = new Map(graphState.nodeTypes);
        newTypes.set(id, (message.data.valueType as string) || 'unknown');
        graphState.nodeTypes = newTypes;

        if (message.data.ownerId) {
            const newControllers = new Map(graphState.nodeControllers);
            newControllers.set(id, message.data.ownerId as string);
            graphState.nodeControllers = newControllers;
        }

        if (message.data.scopeId) {
            const newScopes = new Map(graphState.nodeScopes);
            newScopes.set(id, String(message.data.scopeId));
            graphState.nodeScopes = newScopes;
        }
    }

    // Handle dispose - remove node and its edges
    if (message.data?.event === 'dispose' && message.data.id) {
        const id = message.data.id as string;
        graphState.edges = graphState.edges.filter(
            e => e.source !== id && e.target !== id
        );

        const newNames = new Map(graphState.nodeNames);
        newNames.delete(id);
        graphState.nodeNames = newNames;

        const newTypes = new Map(graphState.nodeTypes);
        newTypes.delete(id);
        graphState.nodeTypes = newTypes;

        const newControllers = new Map(graphState.nodeControllers);
        newControllers.delete(id);
        graphState.nodeControllers = newControllers;

        const newScopes = new Map(graphState.nodeScopes);
        newScopes.delete(id);
        graphState.nodeScopes = newScopes;

        const newComputedIds = new Set(graphState.computedIds);
        newComputedIds.delete(id);
        graphState.computedIds = newComputedIds;
    }

    // Handle app disconnect - clear graph
    if (message.type === 'app_disconnected') {
        graphState.edges = [];
        graphState.nodeNames = new Map();
        graphState.nodeTypes = new Map();
        graphState.nodeControllers = new Map();
        graphState.nodeScopes = new Map();
        graphState.computedIds = new Set();
    }

    // Handle init - reset graph
    if (message.type === 'init') {
        graphState.edges = [];
        graphState.nodeNames = new Map();
        graphState.nodeTypes = new Map();
        graphState.nodeControllers = new Map();
        graphState.nodeScopes = new Map();
        graphState.computedIds = new Set();
    }
});
