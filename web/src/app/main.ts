import { createPinia } from 'pinia';
import { createApp } from 'vue';
import '@/shared/theme/global.css';
import { registerMingcuteIcons } from '@/shared/ui/mingcute-registry';
import App from './App.vue';
import { router } from './router';

registerMingcuteIcons();

const app = createApp(App);
app.use(createPinia());
app.use(router);
app.mount('#app');
