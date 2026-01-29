import {defineConfig} from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
    plugins: [
        RubyPlugin(),
    ],

    build: {
        minify: false
    },

    resolve: {
        dedupe: ['@primer/view-components', '@github/catalyst']
    },

    optimizeDeps: {
        include: ['@primer/view-components'],
        esbuildOptions: {
            keepNames: true
        }
    },

    server: {
        hmr: {
            overlay: true
        }
    },


})
