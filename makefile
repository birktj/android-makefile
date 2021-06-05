SDK := /opt/android-sdk
PLATFORM_VERSION := 30
SDK_VERSION := 30.0.2

# See https://maven.google.com/web/index.html for list of libraries
LIBS = androidx.core:core:1.2.0:aar \
	   androidx.activity:activity:1.1.0:aar \
	   androidx.fragment:fragment:1.2.3:aar \
	   androidx.appcompat:appcompat:1.1.0:aar \
	   androidx.appcompat:appcompat-resources:1.1.0:aar \
	   androidx.lifecycle:lifecycle-common:2.2.0:jar \
	   androidx.lifecycle:lifecycle-viewmodel:2.2.0:aar \
	   androidx.lifecycle:lifecycle-runtime:2.2.0:aar \
	   androidx.savedstate:savedstate:1.0.0:aar \
	   androidx.drawerlayout:drawerlayout:1.0.0:aar \
	   androidx.collection:collection:1.1.0:jar \
	   androidx.arch.core:core-common:2.1.0:jar \
	   androidx.vectordrawable:vectordrawable:1.1.0:aar \
	   androidx.customview:customview:1.0.0:aar

PACKAGE_NAME = com.example.android.makefile
SOURCE_DIR = src

KEYSTORE?= keystore.jks

# NOTE: DO NOT OVERRIDE THE PASSWORD HERE, instead set it as an enviroment
# variable
KEYSTORE_PASS?= "password"


# Generated variables
PLATFORM = $(SDK)/platforms/android-$(PLATFORM_VERSION)
BUILD_TOOLS = $(SDK)/build-tools/$(SDK_VERSION)

PACKAGE_PATH = $(subst .,/,$(PACKAGE_NAME))

kotlin_files := $(shell find $(SOURCE_DIR) -type f -name '*.kt')

lib_package = $(word 1, $(subst :, ,$1))
lib_name    = $(word 2, $(subst :, ,$1))
lib_version = $(word 3, $(subst :, ,$1))
lib_type    = $(word 4, $(subst :, ,$1))
lib_filename = $(call lib_name,$1)-$(call lib_version,$1).$(call lib_type,$1)

LIBS_NAME = $(foreach lib,$(LIBS),$(call lib_package,$(lib))/$(call lib_name,$(lib))-$(call lib_version,$(lib)))

LIBS_RAW = $(foreach lib,$(LIBS), $(subst .,/,$(call lib_package,$(lib)))/$(call lib_name,$(lib))/$(call lib_version,$(lib))/$(call lib_filename,$(lib)))
LIBS_DOWNLOAD = $(addprefix build/download/, $(LIBS_RAW))
LIBS_DOWNLOAD_AAR = $(filter %.aar, $(LIBS_DOWNLOAD))
LIBS_DOWNLOAD_JAR = $(filter %.jar, $(LIBS_DOWNLOAD))

LIBS_AAR_EXTRACTED = $(LIBS_DOWNLOAD_AAR:build/download/%.aar=build/libs/extracted/%)
LIBS_AAR_COMPILED  = $(LIBS_DOWNLOAD_AAR:build/download/%.aar=build/libs/compiled/%.zip)
LIBS_AAR_R_JAVA    = $(LIBS_DOWNLOAD_AAR:build/download/%.aar=build/libs-gen/%)
LIBS_AAR_R_JAVA_FILE  = $(foreach dir,$(LIBS_AAR_R_JAVA),$(shell find $(dir) -type f -name '*.java'))
LIBS_JAR_FILES = $(LIBS_DOWNLOAD_JAR) $(addsuffix /classes.jar, $(LIBS_AAR_EXTRACTED))

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
LIBS_CP_FLAGS = $(subst $(SPACE),:,$(LIBS_JAR_FILES))
LIBS_RES_FLAGS = $(addprefix -S , $(addsuffix /res, $(LIBS_AAR_EXTRACTED)))
LIBS_INCLUDE_FLAGS = $(addprefix -I , $(LIBS_DOWNLOAD))
LIBS_LINK_FLAGS = $(addprefix -R , $(LIBS_AAR_COMPILED))

all: build/app.apk
.PHONY: all

$(LIBS_DOWNLOAD):
	$(eval package=$(subst .,/,$(word 1, $(subst /, ,$(@:build/download/%.aar=%)))))
	$(eval name_version=$(word 2, $(subst /, ,$(@:build/download/%.aar=%))))
	$(eval version=$(lastword $(subst -, ,$(name_version))))
	$(eval name=$(name_version:%-$(version)=%))
	@mkdir -p $(shell dirname $@)
	wget maven.google.com/$(@:build/download/%=%) \
		-P $(shell dirname $@)
	touch -c $@

$(LIBS_AAR_EXTRACTED): build/libs/extracted/%: build/download/%.aar
	@mkdir -p $@
	@mkdir -p $@/res
	unzip -o $< -d $@

$(LIBS_AAR_COMPILED):
	@mkdir -p $@
	$(BUILD_TOOLS)/aapt2 compile --dir $(@:build/libs/compiled/%.zip=build/libs/extracted/%) -o $@

$(LIBS_AAR_R_JAVA): build/libs-gen/%: build/libs/extracted/%
	@mkdir -p $@
	@touch -c $@
	$(BUILD_TOOLS)/aapt package -f -m -J $@ $(LIBS_RES_FLAGS) -M $</AndroidManifest.xml -I $(PLATFORM)/android.jar --auto-add-overlay

build/gen/$(PACKAGE_PATH)/R.java: $(LIBS_AAR_EXTRACTED)
	@mkdir -p build/gen/$(PACKAGE_PATH)
	$(BUILD_TOOLS)/aapt package -f -m -J build/gen/ -S res $(LIBS_RES_FLAGS) -M AndroidManifest.xml -I $(PLATFORM)/android.jar --auto-add-overlay

build/classes: build/gen/$(PACKAGE_PATH)/R.java $(kotlin_files) $(LIBS_JAR_FILES) $(LIBS_AAR_R_JAVA)
	@mkdir -p build/classes
	javac -source 8 -target 8 -cp $(PLATFORM) -d build/classes build/gen/$(PACKAGE_PATH)/R.java $(LIBS_AAR_R_JAVA_FILE)
	kotlinc -cp $(PLATFORM)/android.jar:$(LIBS_CP_FLAGS):build/classes -d build/classes $(kotlin_files)
	touch -c build/classes

build/apk/classes.dex: build/classes $(LIBS_JAR_FILES)
	@mkdir -p build/apk
	$(BUILD_TOOLS)/dx --dex --output=build/apk/classes.dex build/classes $(LIBS_JAR_FILES)

build/app.apk: build/apk/classes.dex $(LIBS_AAR_EXTRACTED) $(LIBS_DOWNLOAD)
	$(BUILD_TOOLS)/aapt package --auto-add-overlay -S res $(LIBS_RES_FLAGS) -f -m -M AndroidManifest.xml -I $(PLATFORM)/android.jar $(LIBS_INCLUDE_FLAGS) -F build/app.apk build/apk/
	$(BUILD_TOOLS)/apksigner sign --ks $(KEYSTORE) --ks-pass "pass:$(KEYSTORE_PASS)" build/app.apk	

upload: build/app.apk
	$(SDK)/platform-tools/adb install -r build/app.apk
.PHONY: upload

run: upload
	$(SDK)/platform-tools/adb shell monkey -p $(PACKAGE_NAME) 1
.PHONY: run

clean:
	rm -rf build
.PHONY: clean
