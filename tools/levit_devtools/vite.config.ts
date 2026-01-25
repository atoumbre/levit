import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { createDevToolsServer } from './src/server/ws-server';

const wsServer = {
	name: 'ws-server',
	configureServer(server: any) {
		createDevToolsServer(server.httpServer);
	}
};

export default defineConfig({
	plugins: [sveltekit(), wsServer],
	server: {
		port: 8080,
		strictPort: true,
	}
});
