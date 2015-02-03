APPLICATION_PATH = /usr/share/applications
BIN_PATH = /usr/bin
PIXMAP_PATH = /usr/share/pixmaps

DESKTOP_FILE = birc.desktop
ICON_FILE = birc.png
BIN_FILE = birc.rb
BIN_NAME = birc

install:
	@cp $(DESKTOP_FILE) $(APPLICATION_PATH)/$(DESKTOP_FILE)
	@cp $(BIN_FILE) $(BIN_PATH)/$(BIN_FILE)
	@mkdir -p $(PIXMAP_PATH)/$(BIN_NAME)
	@cp $(ICON_FILE) $(PIXMAP_PATH)/$(BIN_NAME)/$(ICON_FILE)
	@ln -s $(BIN_PATH)/$(BIN_FILE) $(BIN_PATH)/$(BIN_NAME)
