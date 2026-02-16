import {defineConfig} from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
    plugins: [
        RubyPlugin(),
    ],

    build: {
        minify: false,
        rollupOptions: {
            output: {
                manualChunks: undefined
            }
        }
    },

    resolve: {
        dedupe: [
            '@primer/view-components',
            '@github/catalyst',
            '@github/relative-time-element',
            '@github/clipboard-copy-element',
            '@github/details-menu-element',
            '@github/include-fragment-element',
            '@github/image-crop-element'
        ],
        alias: [
            {
                find: /^@primer\/view-components$/,
                replacement: '@primer/view-components/app/assets/javascripts/primer_view_components.js'
            }
        ]
    },

    optimizeDeps: {
        include: [
            '@primer/view-components',
            '@github/catalyst'
        ],
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
