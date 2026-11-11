import { mount } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { describe, expect, it } from 'vitest';
import { createMemoryHistory, createRouter } from 'vue-router';
import LoginPage from '@/features/auth/pages/login-page.vue';
import { useLocale } from '@/shared/i18n/use-locale';
import { useTheme } from '@/shared/theme/use-theme';
import { registerMingcuteIcons } from '@/shared/ui/mingcute-registry';

registerMingcuteIcons();

describe('LoginPage', () => {
  it('renders 80/20 hero + form shell, switches light/dark hero, and updates en/es locale & Sxnnyside link', async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/login', component: LoginPage },
        { path: '/catalog', component: { template: '<div />' } },
      ],
    });
    await router.push('/login');
    await router.isReady();

    const { setTheme } = useTheme();
    const { setLocale } = useLocale();
    setTheme('light');
    setLocale('es');

    const wrapper = mount(LoginPage, {
      global: {
        plugins: [createPinia(), router],
      },
    });

    const imgLight = wrapper.find('.login-hero__image').attributes('src');
    expect(imgLight).toContain('login-hero-light');

    const creditEs = wrapper.find('.sxnnyside-credit');
    expect(creditEs.text()).toContain('Desarrollado por Sxnnyside Scholarships');
    expect(creditEs.attributes('href')).toBe(
      'https://www.sxnnysideproject.com/es/realms/sxnnyside-scholarships/',
    );

    await wrapper.find('.locale-toggle').trigger('click');
    const creditEn = wrapper.find('.sxnnyside-credit');
    expect(creditEn.text()).toContain('Developed by Sxnnyside Scholarships');
    expect(creditEn.attributes('href')).toBe(
      'https://www.sxnnysideproject.com/en/realms/sxnnyside-scholarships/',
    );

    await wrapper.find('.theme-toggle').trigger('click');
    const imgDark = wrapper.find('.login-hero__image').attributes('src');
    expect(imgDark).toContain('login-hero-dark');
  });
});
