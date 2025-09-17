packer {
    required_plugins {
        tart = {
            version = ">= 1.12.0"
            source  = "github.com/cirruslabs/tart"
        }
    }
}

variable "xcode_version" {
  type = string
}

source "tart-cli" "tart" {
    vm_base_name = "registry.hub.docker.com/ackee/tart-macos-base:sequoia"
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

    # xcode
    provisioner "shell" {
        inline = [
            "echo 'export PATH=/usr/local/bin/:$PATH' >> ~/.zprofile",
            "source ~/.zprofile",
            "brew install xcodesorg/made/xcodes",
            "echo 'Starting Xcode installation'",
            "xcodes install ${var.xcode_version} --experimental-unxip --path ~/Downloads/Xcode_${var.xcode_version}.xip",
            "echo 'Xcode installed'",
            "sudo rm -rf ~/Downloads/Xcode_${var.xcode_version}.xip",
            "rm -rf ~/.Trash/Xcode_${var.xcode_version}.xip",
            "sudo rm -rf ~/.Trash/Xcode_${var.xcode_version}.xip",
            "xcodes select ${var.xcode_version}",
            "xcodebuild -downloadPlatform ios",
            "xcodebuild -runFirstLaunch",
            "/usr/sbin/softwareupdate --install-rosetta --agree-to-license",
            # enable all plugins
            "defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES",
            # enable all macros
            "defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES",
        ]
    }

    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install carthage unzip zip ca-certificates mint",
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
            "mise install tuist swiftlint --yes",
            "xcrun simctl create 'iPhone 13 Pro Max' 'iPhone 13 Pro Max'",
        ]
    }

    # KMM
    provisioner "shell" {
        inline = [
            "source ~/.zprofile",
            "brew install openjdk@17",
            "echo 'export PATH=\"/opt/homebrew/opt/openjdk@17/bin:$PATH\"' >> ~/.zprofile",
            "echo 'export CPPFLAGS=\"-I/opt/homebrew/opt/openjdk@17/include:$CPPFLAGS\"' >> ~/.zprofile",
            "echo 'export JAVA_HOME=\"/opt/homebrew/opt/openjdk@17\"' >> ~/.zprofile",
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