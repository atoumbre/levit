// WebSocket connection store using Svelte 5 runes
import type { ConnectionStatus, ServerMessage } from '../types';

// Export reactive state directly for Svelte 5 reactivity
export const connectionState = $state<{ status: ConnectionStatus }>({ status: 'disconnected' });

let ws: WebSocket | null = null;
let messageHandlers: ((message: ServerMessage) => void)[] = [];

export function connect(url: string = 'ws://localhost:8080/dashboard'): void {
    if (ws && ws.readyState === WebSocket.OPEN) return;

    connectionState.status = 'connecting';
    ws = new WebSocket(url);

    ws.onopen = () => {
        connectionState.status = 'connected';
        console.log('[LevitDevTools] Connected to server');
    };

    ws.onclose = () => {
        connectionState.status = 'disconnected';
        console.log('[LevitDevTools] Disconnected, retrying in 3s...');
        setTimeout(() => connect(url), 3000);
    };

    ws.onerror = (error) => {
        console.error('[LevitDevTools] WebSocket error:', error);
    };

    ws.onmessage = (event) => {
        try {
            const message = JSON.parse(event.data) as ServerMessage;
            messageHandlers.forEach((handler) => handler(message));
        } catch (e) {
            console.error('[LevitDevTools] Failed to parse message:', e);
        }
    };
}

export function disconnect(): void {
    if (ws) {
        ws.close();
        ws = null;
    }
}

export function onMessage(handler: (message: ServerMessage) => void): () => void {
    messageHandlers.push(handler);
    return () => {
        messageHandlers = messageHandlers.filter((h) => h !== handler);
    };
}

export function send(data: unknown): void {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(data));
    }
}
