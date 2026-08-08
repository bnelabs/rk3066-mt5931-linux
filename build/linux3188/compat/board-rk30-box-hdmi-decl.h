/*
 * Linux3188 compatibility declaration.
 *
 * board-rk30-box.c assigns hdmi_init_lcdc as a callback when HDMI and LCDC1
 * are enabled, but the public 3.0.36 headers do not declare the function
 * implemented by drivers/video/rockchip/hdmi/hdmi-lcdc.c. GCC 4.6 accepted
 * the undeclared callback in the historical build; GCC 12 rejects it.
 *
 * This forward declaration changes no ABI or generated behavior. It is
 * injected only by the disposable component builder.
 */
struct rk29fb_screen;
struct rk29lcd_info;
extern void hdmi_init_lcdc(struct rk29fb_screen *screen,
	struct rk29lcd_info *lcd_info);
