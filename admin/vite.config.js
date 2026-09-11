import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Production path: https://app.sugatai.com/workadmin/
const base = process.env.VITE_BASE_PATH || '/workadmin/';

export default defineConfig({
  base,
  plugins: [react()],
  server: {
    port: 5174,
    proxy: {
      '/admin': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
      // Local uploads served by FastAPI in development
      '/uploads': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
});
