import { WebSocketServer, WebSocket } from 'ws';
import type { IncomingMessage } from 'http';

// Types reflecting the Dart implementation
interface AppState {
    id: string;
    name: string;
    connectedAt: string;
    registry: Map<string, any>;
    reactive: Map<string, any>;
    socket: WebSocket;
}

interface ServerMessage {
    type: string;
    [key: string]: any;
}

// Global state
const dashboardClients = new Set<WebSocket>();
const appClients = new Map<WebSocket, AppState>();
let appCounter = 0;

export function createDevToolsServer(server: any) {
    const wss = new WebSocketServer({ noServer: true });

    server.on('upgrade', (request: IncomingMessage, socket: any, head: any) => {
        const { pathname } = new URL(request.url || '', `http://${request.headers.host}`);

        if (pathname === '/ws') {
            wss.handleUpgrade(request, socket, head, (ws) => {
                const { searchParams } = new URL(request.url || '', `http://${request.headers.host}`);
                const appId = searchParams.get('appId');
                handleAppConnection(ws, appId);
            });
        } else if (pathname === '/dashboard') {
            wss.handleUpgrade(request, socket, head, (ws) => {
                handleDashboardConnection(ws);
            });
        } else {
            // Let other handlers (like Vite HMR) handle it if needed, 
            // but usually we just destroy if we are strictly the WS server.
            // However, in Vite dev mode, Vite handles its own upgrades.
            // We should only handle OUR paths.
            // If we are attached to the same server, we must be careful not to destroy Vite's connections.
            // But 'upgrade' event listeners are additive. 
            // If request.url matches, we handle it.
            // Ideally check pathname before calling handleUpgrade.
        }
    });

    console.log('[DevTools] WebSocket server attached to Vite/Http server');
}

function handleDashboardConnection(ws: WebSocket) {
    console.log('[Dashboard] Client connected');
    dashboardClients.add(ws);

    sendFullStateToClient(ws);

    ws.on('close', () => {
        console.log('[Dashboard] Client disconnected');
        dashboardClients.delete(ws);
    });
}

function handleAppConnection(ws: WebSocket, requestedAppId: string | null) {
    let appId = requestedAppId;
    let name = '';

    if (appId) {
        // Check if there is an existing connection for this appId
        for (const [client, state] of appClients.entries()) {
            if (state.id === appId) {
                console.log(`[App] Replacing existing connection for ${appId}`);
                // Don't close the socket immediately to avoid firing close handler behaviors that might cleanup the ID
                // actually, we WANT to cleanup the old invalid state.
                // But if we close it, it triggers 'close' event which removes it from appClients.
                client.terminate();
                break;
            }
        }
        name = appId; // Use ID as name if provided, or could pass name too
    } else {
        appCounter++;
        appId = `app_${appCounter}`;
        name = `App #${appCounter}`;
    }

    const appState: AppState = {
        id: appId!,
        name: name,
        connectedAt: new Date().toISOString(),
        registry: new Map(),
        reactive: new Map(),
        socket: ws
    };

    appClients.set(ws, appState);
    console.log(`[App] Client connected: ${appState.name} (${appState.id})`);

    // Notify connected
    broadcastToDashboards({
        type: 'app_connected',
        appId: appState.id,
        appName: appState.name,
        connectedAt: appState.connectedAt
    });


    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message.toString());
            handleAppEvent(ws, data);
        } catch (e) {
            console.error('[App] Error parsing message:', e);
        }
    });

    ws.on('close', () => {
        // Only broadcast disconnect if this socket is still the active one for this ID?
        // But appClients is keyed by ws, so this closure captures 'ws'.
        const state = appClients.get(ws);
        if (state) {
            console.log(`[App] Client disconnected: ${state.name} (${state.id})`);
            broadcastToDashboards({
                type: 'app_disconnected',
                appId: state.id,
                registry: Array.from(state.registry.keys()),
                reactive: Array.from(state.reactive.keys())
            });
            appClients.delete(ws);
            dashboardClients.forEach(client => sendFullStateToClient(client));
        }
    });
}

function handleAppEvent(ws: WebSocket, data: any) {
    const state = appClients.get(ws);
    if (!state) return;

    const category = data.category;
    const event = data.event;

    // Add appId
    data.appId = state.id;

    if (category === 'di') {
        const key = data.key;
        const scopeId = data.scopeId;

        if (event && key && scopeId) {
            const fullKey = `${scopeId}:${key}`;
            if (event === 'register') {
                state.registry.set(fullKey, data);
            } else if (event === 'delete') {
                state.registry.delete(fullKey);
            }
        }
    } else if (category === 'state') {
        const id = data.id;
        // Support both 'type' (legacy) and 'event' (new protocol)
        const stateEvent = data.type || event;

        if (id && stateEvent) {
            if (stateEvent === 'init' || stateEvent === 'update' || stateEvent === 'flags_updated' || stateEvent === 'register') {
                const existing = state.reactive.get(id) || {};
                // Normalize: add 'event' field for UI compatibility
                state.reactive.set(id, { ...existing, ...data, event: stateEvent });
            } else if (stateEvent === 'dispose') {
                state.reactive.delete(id);
            }
        }
    }

    broadcastToDashboards({ type: 'event', data });
}

function sendFullStateToClient(ws: WebSocket) {
    if (ws.readyState !== WebSocket.OPEN) return;

    const allRegistry: any[] = [];
    const allReactive: any[] = [];
    const apps: any[] = [];

    for (const state of appClients.values()) {
        apps.push({
            id: state.id,
            name: state.name,
            connectedAt: state.connectedAt,
            registryCount: state.registry.size,
            reactiveCount: state.reactive.size
        });

        for (const item of state.registry.values()) {
            allRegistry.push({ ...item, appId: state.id });
        }
        for (const item of state.reactive.values()) {
            allReactive.push({ ...item, appId: state.id });
        }
    }

    ws.send(JSON.stringify({
        type: 'init',
        apps,
        registry: allRegistry,
        reactive: allReactive
    }));
}

function broadcastToDashboards(message: ServerMessage) {
    const encoded = JSON.stringify(message);
    for (const client of dashboardClients) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(encoded);
        }
    }
}
