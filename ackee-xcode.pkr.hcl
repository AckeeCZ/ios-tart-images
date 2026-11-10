packer {
    required_plugins {
        tart = {
            version = ">= 1.21.0"
            source  = "github.com/cirruslabs/tart"
        }
    }
}

variable "xcode_version" {
  type = string
}

source "tart-cli" "tart" {
    vm_base_name = "registry.hub.docker.com/ackee/tart-macos-base:golden-gate"
    vm_name      = "ackee-xcode:${var.xcode_version}"
    cpu_count    = 4
    memory_gb    = 8
    disk_size_gb = 100
    ssh_password = "admin"
    ssh_username = "admin"
    ssh_timeout  = "120s"
    headless     = true
}

build {
    sources = ["source.tart-cli.tart"]

    provisioner "file" {
        source      = pathexpand("~/Downloads/Xcode_${var.xcode_version}.xip")
        destination = "/Users/admin/Downloads/Xcode_${var.xcode_version}.xip"
    }

    # disable Spotlight indexing (before the Xcode install so it does not index the unpacked app)
    provisioner "shell" {
        inline = [
            "echo 'Disabling spotlight...'",
            "sudo mdutil -a -i off",
            "sudo mdutil -a -E || true"
        ]
    }

    # xcode
    provisioner "shell" {
        inline = [
            "echo 'export PATH=/usr/local/bin/:$PATH' >> ~/.zprofile",
            "source ~/.zprofile",
            "brew install xcodes",
            "echo 'Starting Xcode installation'",
            "sudo xcodes install ${var.xcode_version} --experimental-unxip --path /Users/admin/Downloads/Xcode_${var.xcode_version}.xip --select --empty-trash",
            "echo 'Xcode installed'",
            "xcodebuild -downloadPlatform ios",
            "xcodebuild -runFirstLaunch",
            "/usr/sbin/softwareupdate --install-rosetta --agree-to-license",
            # enable all plugins
            "defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES",
            # enable all macros
            "defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES",
            # enable prebuilt SPM packages
            "defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES"
        ]
    }

    # Make Xcode discoverable for tools that locate it via LaunchServices (e.g. Crashlytics upload-symbols)
    provisioner "shell" {
        inline = [
            "XCODE_APP=\"$(dirname \"$(dirname \"$(xcode-select -p)\")\")\"",
            "echo \"Registering $XCODE_APP in LaunchServices\"",
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f \"$XCODE_APP\"",
            "echo \"export DEVELOPER_DIR=$(xcode-select -p)\" >> ~/.zprofile",
            "source ~/.zprofile",
            "echo \"DEVELOPER_DIR=$DEVELOPER_DIR\""
        ]
    }

    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install carthage unzip zip ca-certificates xcbeautify",
        ]
    }

    # inspired by https://github.com/actions/runner-images/blob/fb3b6fd69957772c1596848e2daaec69eabca1bb/images/macos/provision/configuration/configure-machine.sh#L33-L61
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "sudo security delete-certificate -Z FF6797793A3CD798DC5B2ABEF56F73EDC9F83A64 /Library/Keychains/System.keychain",
            "sudo mkdir -p /usr/local/bin/",
            "curl -o add-certificate.swift https://raw.githubusercontent.com/actions/runner-images/fb3b6fd69957772c1596848e2daaec69eabca1bb/images/macos/provision/configuration/add-certificate.swift",
            "swiftc add-certificate.swift",
            "sudo mv ./add-certificate /usr/local/bin/add-certificate",
            "curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer",
            "curl -o DeveloperIDG2CA.cer https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer",
            "sudo add-certificate AppleWWDRCAG3.cer",
            "sudo add-certificate DeveloperIDG2CA.cer",
            "rm add-certificate* *.cer"
        ]
    }

    # mise & tuist
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "curl https://mise.run | sh",
            "~/.local/bin/mise activate --shims >> ~/.zprofile",
            "source ~/.zprofile",
            "mise version",
            "mise install tuist swiftlint --yes",
            "xcrun simctl delete all",
            "xcrun simctl create 'iPhone 13 Pro Max' 'iPhone 13 Pro Max'",
            "xcrun simctl create 'iPhone 17 Pro' 'iPhone 17 Pro'",
            "xcrun simctl create 'iPhone 17 Pro Max' 'iPhone 17 Pro Max'",
        ]
    }

    # KMP
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install openjdk@21",
            "echo 'export PATH=\"/opt/homebrew/opt/openjdk@21/bin:$PATH\"' >> ~/.zprofile",
            "echo 'export CPPFLAGS=\"-I/opt/homebrew/opt/openjdk@21/include:$CPPFLAGS\"' >> ~/.zprofile",
            # the brew opt prefix is not a JDK home; java_home and Gradle need the libexec bundle
            "echo 'export JAVA_HOME=\"/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home\"' >> ~/.zprofile",
            "sudo ln -sfn /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk",
            "/usr/libexec/java_home -v 21",
        ]
    }

    # Android SDK for KMP / React Native builds
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install --cask android-commandlinetools",
            "echo 'export ANDROID_HOME=\"$HOME/Library/Android/sdk\"' >> ~/.zprofile",
            "echo 'export ANDROID_SDK_ROOT=\"$ANDROID_HOME\"' >> ~/.zprofile",
            "echo 'export PATH=\"$ANDROID_HOME/platform-tools:$PATH\"' >> ~/.zprofile",
            "source ~/.zprofile",
            # licenses first, otherwise --install blocks on an interactive prompt
            "yes | sdkmanager --sdk_root=\"$ANDROID_HOME\" --licenses > /dev/null",
            "yes | sdkmanager --sdk_root=\"$ANDROID_HOME\" --install 'platform-tools' 'platforms;android-35' 'platforms;android-36' 'platforms;android-37.0' 'build-tools;35.0.0' 'build-tools;36.0.0' > /dev/null",
            "sdkmanager --sdk_root=\"$ANDROID_HOME\" --list_installed",
        ]
    }

    # React Native - Expo
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "echo Install yarn node fastlane cocoapods",
            "brew install yarn node@20 fastlane cocoapods",
            "echo Link node",
            "brew link --overwrite node@20",
            "echo Enable corepack",
            "corepack enable",
            "echo Corepack use yarn",
            "corepack use yarn@4",
            "echo Run npm i",
            "npm i -g eas-cli"
        ]
    }

    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew cleanup -s --prune=all || true",
            "find \"$(brew --cache)\" -mindepth 1 -maxdepth 1 ! -name api -exec rm -rf {} + || true",
        ]
    }

    // check there is at least 15GB of free space and fail if not
    provisioner "shell" {
        inline = [
        "source ~/.zprofile",
        "echo Checking disk space",
        "df -h",
        "export FREE_MB=$(df -m | awk '{print $4}' | head -n 2 | tail -n 1)",
        "echo Available space in MB = $FREE_MB",
        "[[ $FREE_MB -gt 15000 ]] && echo OK || exit 1",
        ]
    }
}