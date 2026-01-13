// Types for Levit DevTools

export interface AppInfo {
    id: string;
    name: string;
    connectedAt: string;
    registryCount?: number;
    reactiveCount?: number;
}

export interface RegistryItem {
    key: string;
    fullKey?: string;  // Unique key: scopeId:key
    type: string;
    scope: string;
    scopeId: number;
    parentScopeId?: number;
    appId?: string;
    isLazy?: boolean;
    isFactory?: boolean;
    isAsync?: boolean;
    permanent?: boolean;
    tag?: string;
}

export interface ReactiveItem {
    id: string;
    name?: string;
    ownerId?: string;
    scopeId?: string;
    valueType?: string;
    newValue: unknown;
    oldValue?: unknown;
    timestamp?: string;
    appId?: string;
    dependencies?: string[];  // IDs of dependencies (for computed)
    flags?: {
        name?: string;
        controller?: string;
        scopeId?: string;
    };
}

export interface EventItem {
    id?: string;
    category: 'di' | 'state';
    event: string;
    key?: string;
    name?: string;
    ownerId?: string;
    scopeId?: number;
    scope?: string;
    newValue?: unknown;
    oldValue?: unknown;
    timestamp: string;
    appId?: string;
    dependencies?: string[];  // IDs of dependencies (for dependencies_updated events)
    [key: string]: unknown;
}

export interface ServerMessage {
    type: 'init' | 'event' | 'app_connected' | 'app_disconnected';
    apps?: AppInfo[];
    registry?: RegistryItem[];
    reactive?: ReactiveItem[];
    data?: EventItem;
    appId?: string;
    appName?: string;
    connectedAt?: string;
}

export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected';
