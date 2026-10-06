#!/bin/bash
cd openwrt
# 强制使用 6.12 内核版本
echo "CONFIG_LINUX_6_12=y" >> .config
sed -i 's/KERNEL_PATCHVER:=.*/KERNEL_PATCHVER:=6.12/' target/linux/armvirt/Makefile

clone_retry() {
  local repo="$1"
  local target="$2"
  for attempt in 1 2 3; do
    git clone --depth 1 "$repo" "$target" && return 0
    rm -rf "$target"
    sleep 5
  done
  echo "Failed to clone $repo after 3 attempts" >&2
  return 1
}

# Add luci-app-adguardhome
clone_retry https://github.com/rufengsuixing/luci-app-adguardhome.git package-temp/luci-app-adguardhome
mv -f package-temp/luci-app-adguardhome package/lean/
rm -rf package-temp

# Add luci-theme-opentomcat
clone_retry https://github.com/Leo-Jo-My/luci-theme-opentomcat.git theme-temp/luci-theme-opentomcat
rm -rf theme-temp/luci-theme-opentomcat/LICENSE
rm -rf theme-temp/luci-theme-opentomcat/README.md
mv -f theme-temp/luci-theme-opentomcat package/lean/
rm -rf theme-temp

# Add luci-app-amlogic
clone_retry https://github.com/ophub/luci-app-amlogic.git package-temp/luci-app-amlogic
mv -f package-temp/luci-app-amlogic/luci-app-amlogic package/lean/
rm -rf package-temp
# ==================== AIC8800 USB Driver ====================
# 1. 下载驱动源码（使用 clone_retry 防止网络波动）
clone_retry https://github.com/jzitnik/AIC8800.git package/aic8800

# 2. 修复 Linux 6.18 内核 API 变更（补全缺失的 GFP_ATOMIC 参数）
sed -i 's/cfg80211_rx_spurious_frame(\([^)]*\))/cfg80211_rx_spurious_frame(\1, GFP_ATOMIC)/g' package/aic8800/aic8800_fdrv/rwmx_rx.c
sed -i 's/cfg80211_rx_unexpected_4addr_frame(\([^)]*\))/cfg80211_rx_unexpected_4addr_frame(\1, GFP_ATOMIC)/g' package/aic8800/aic8800_fdrv/rwmx_rx.c

# 3. 生成 OpenWrt 软件包 Makefile
cat > package/aic8800/Makefile << 'EOF'
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=aic8800
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/aic8800
  SUBMENU:=Wireless Drivers
  TITLE:=AIC8800 WiFi driver (for kernel 6.18+)
  DEPENDS:=+kmod-cfg80211 +kmod-mac80211 +kmod-usb-core
  FILES:=$(PKG_BUILD_DIR)/aic8800_fdrv.ko $(PKG_BUILD_DIR)/aic_load_fw.ko
  AUTOLOAD:=$(call AutoLoad,50,aic8800_fdrv aic_load_fw)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./aic8800_fdrv $(PKG_BUILD_DIR)/
	$(CP) ./aic_load_fw $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		M="$(PKG_BUILD_DIR)/aic8800_fdrv" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		modules
	$(MAKE) -C "$(LINUX_DIR)" \
		M="$(PKG_BUILD_DIR)/aic_load_fw" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		modules
endef

$(eval $(call KernelPackage,aic8800))
EOF

# 4. 将驱动加入配置
echo "CONFIG_PACKAGE_kmod-aic8800=y" >> .config
