# Makefile for CrystalQuickLook (macOS App + QuickLook Extension)

CC = clang
ARCH = arm64
MIN_MACOS = 12.0
CFLAGS = -fobjc-arc -target $(ARCH)-apple-macos$(MIN_MACOS) -O2
SHARED_SRCS = Shared/ElementData.m Shared/CrystalModel.m Shared/CIFParser.m Shared/POSCARParser.m Shared/CrystalSceneBuilder.m Shared/CrystalCompassNode.m Shared/CrystalViewController.m
SHARED_INCS = -I Shared

BUILD_DIR = build
APP_NAME = CrystalQuickLook.app
APPEX_NAME = CrystalQuickLookPreview.appex

APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME)
APPEX_BUNDLE = $(BUILD_DIR)/$(APPEX_NAME)
INSTALL_DIR = $(HOME)/Applications

.PHONY: all clean install uninstall test help

all: app

# 1. Build QuickLook Extension
extension:
	@echo "==> Building QuickLook Preview Extension..."
	@mkdir -p $(APPEX_BUNDLE)/Contents/MacOS
	@mkdir -p $(APPEX_BUNDLE)/Contents/Resources
	$(CC) $(CFLAGS) $(SHARED_INCS) \
		-framework Foundation -framework AppKit -framework SceneKit -framework QuickLookUI \
		$(SHARED_SRCS) QuickLookExtension/PreviewViewController.m QuickLookExtension/main.m \
		-o $(APPEX_BUNDLE)/Contents/MacOS/CrystalQuickLookPreview
	@cp QuickLookExtension/Info.plist $(APPEX_BUNDLE)/Contents/
	@codesign -s - --force --entitlements QuickLookExtension/CrystalQuickLookPreview.entitlements $(APPEX_BUNDLE)
	@echo "    ✓ QuickLook Preview Extension built successfully."

# 2. Build Host Application
app: extension
	@echo "==> Building CrystalQuickLook Host Application..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@mkdir -p $(APP_BUNDLE)/Contents/PlugIns
	$(CC) $(CFLAGS) $(SHARED_INCS) -I App \
		-framework Foundation -framework AppKit -framework SceneKit \
		$(SHARED_SRCS) App/PreferencesWindowController.m App/MainWindowController.m App/AppDelegate.m App/main.m \
		-o $(APP_BUNDLE)/Contents/MacOS/CrystalQuickLook
	@cp App/Info.plist $(APP_BUNDLE)/Contents/
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/; fi
	@rm -rf $(APP_BUNDLE)/Contents/PlugIns/$(APPEX_NAME)
	@cp -R $(APPEX_BUNDLE) $(APP_BUNDLE)/Contents/PlugIns/
	@codesign -s - --force --entitlements QuickLookExtension/CrystalQuickLookPreview.entitlements $(APP_BUNDLE)/Contents/PlugIns/$(APPEX_NAME)
	@codesign -s - --force --entitlements App/CrystalQuickLook.entitlements $(APP_BUNDLE)
	@echo "    ✓ CrystalQuickLook.app built successfully."

# 3. Install to ~/Applications and Register QuickLook
install: app
	@echo "==> Installing CrystalQuickLook to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/$(APP_NAME)
	@cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "==> Registering QuickLook Extension..."
	@pluginkit -a $(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/$(APPEX_NAME)
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $(INSTALL_DIR)/$(APP_NAME)
	@qlmanage -r >/dev/null 2>&1 || true
	@qlmanage -r cache >/dev/null 2>&1 || true
	@echo ""
	@echo "================================================================="
	@echo "  ✨ Installation Completed Successfully! ✨"
	@echo "  Location: $(INSTALL_DIR)/$(APP_NAME)"
	@echo ""
	@echo "  • QuickLook: Select any .cif or POSCAR file in Finder"
	@echo "               and press the SPACEBAR to preview in 3D!"
	@echo "  • Standalone: Open $(INSTALL_DIR)/$(APP_NAME) to view files"
	@echo "               via drag-and-drop or File -> Open."
	@echo "================================================================="

# 4. Uninstall
uninstall:
	@echo "==> Uninstalling CrystalQuickLook..."
	@pluginkit -r $(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/$(APPEX_NAME) 2>/dev/null || true
	@rm -rf $(INSTALL_DIR)/$(APP_NAME)
	@qlmanage -r >/dev/null 2>&1 || true
	@qlmanage -r cache >/dev/null 2>&1 || true
	@echo "    ✓ CrystalQuickLook has been removed."

# 5. Run parser tests
test:
	@echo "==> Running Crystal Structure Parser Tests..."
	@$(CC) $(CFLAGS) $(SHARED_INCS) \
		-framework Foundation -framework AppKit -framework SceneKit \
		$(SHARED_SRCS) test_runner.m -o $(BUILD_DIR)/test_runner
	@$(BUILD_DIR)/test_runner

clean:
	@rm -rf $(BUILD_DIR)
	@echo "    ✓ Cleaned build directory."

help:
	@echo "Available targets:"
	@echo "  make          - Build CrystalQuickLook.app and QuickLook Extension"
	@echo "  make install  - Install to ~/Applications and register QuickLook plugin"
	@echo "  make uninstall- Remove from ~/Applications and unregister plugin"
	@echo "  make test     - Run unit tests on sample CIF and POSCAR files"
	@echo "  make clean    - Remove build artifacts"
