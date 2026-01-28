import {defineConfig} from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
    plugins: [
        RubyPlugin(),
    ],

    build: {
        minify: false
    },

    server: {
        hmr: {
            overlay: true
        }
    },


})
