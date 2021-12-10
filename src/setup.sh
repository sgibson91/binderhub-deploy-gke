#!/bin/bash
# shellcheck disable=SC2046 disable=SC2143

# Check sudo availability
sudo_command=$(command -v sudo)

## Linux install cases
if [[ ${OSTYPE} == 'linux'* ]]; then
	echo "--> This is a Linux build"

	## apt-based systems
	if command -v apt >/dev/null 2>&1; then
		echo "--> Checking system packages and installing any missing packages"
		# Update apt before starting, in case this is a new container
		APTPACKAGES=" \
			curl \
			python \
			openssl \
			jq \
			"

		for package in $APTPACKAGES; do
			if ! dpkg -s "$package" >/dev/null; then
				echo "--> Apt installing $package"
				(${sudo_command} apt update && ${sudo_command} apt install -y "$package") || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			else
				echo "--> $package already installed"
			fi
		done
		if ! command -v gcloud >/dev/null 2>&1; then
			echo "--> Attempting to install Google Cloud SDK with deb packages"
			echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | ${suod_command} tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
			${sudo_command} apt-get -y install apt-transport-https ca-certificates gnupg
			curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | ${suod_command} apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
			# shellcheck disable=SC2015
			${sudo_command} apt-get update && ${sudo_command} apt-get -y install google-cloud-sdk || {
				echo >&2 "--> Google Cloud SDK install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> Google Cloud SDK already installed"
		fi
		if ! command -v kubectl >/dev/null 2>&1; then
			echo "--> Attempting to install kubectl with deb packages"
			${sudo_command} apt-get update && ${sudo_command} apt-get install -y apt-transport-https ca-certificates
			${sudo_command} curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
			echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | ${sudo_command} tee /etc/apt/sources.list.d/kubernetes.list
			(${sudo_command} apt-get update && ${sudo_command} apt-get install -y kubectl) || {
				echo >&2 "--> kubectl install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> kubectl already installed"
		fi
		if ! command -v terraform >/dev/null 2>&1; then
			echo "--> Attempting to install Terraform CLI with deb packages"
			${sudo_command} apt-get update && ${sudo_command} apt-get install -y gnupg software-properties-common
			curl -fsSL https://apt.releases.hashicorp.com/gpg | ${sudo_command} apt-key add -
			${sudo_command} apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
			# shellcheck disable=SC2015
			${sudo_command} apt-get update && ${sudo_command} apt-get install -y terraform || {
				echo >&2 "--> terraform install failed; please install manually and rerun this script."
				exit 1
			}
		fi

	## yum-based systems
	elif command -v yum >/dev/null 2>&1; then
		if [ $(grep -iq centos /etc/redhat-release) ]; then
			echo "***************************************************************"
			echo "* You appear to be running CentOS. A required package, jq, is *"
			echo "* not available from core repositories but can be installed   *"
			echo "* from the epel-release repository. If a jq install fails,    *"
			echo "* run the following command as root (or with sudo) to enable  *"
			echo "* the epel repository:                                        *"
			echo "*                                                             *"
			echo "*                  yum -y install epel-release                *"
			echo "*                                                             *"
			echo "***************************************************************"
		fi
		echo "--> Checking system packages and installing any missing packages"
		YUMPACKAGES=" \
			jq \
			curl \
			python \
			tar \
			which \
			openssl \
			"
		for package in $YUMPACKAGES; do
			if ! rpm -q "$package" >/dev/null; then
				echo "--> Yum installing $package"
				${sudo_command} yum install -y "$package" || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			else
				echo "--> $package already installed"
			fi
		done
		if ! command -v gcloud >/dev/null 2>&1; then
			echo "--> Attempting to install Google Cloud SDK with yum packages"
			${sudo_command} tee -a /etc/yum.repos.d/google-cloud-sdk.repo <<EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
			${sudo_command} yum install -y google-cloud-sdk || {
				echo >&2 "--> Google Cloud SDK install failed; please install manually and re-run this script."
				exit 1
			}
		fi
		if ! command -v kubectl >/dev/null 2>&1; then
			echo "--> Attempting to install kubectl with yum packages"
			echo "[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
" | ${sudo_command} tee /etc/yum.repos.d/kubernetes.repo
			${sudo_command} yum install -y kubectl || {
				echo >&2 "--> kubectl install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> kubectl already installed"
		fi
		if ! command -v terraform >/dev/null 2>&1; then
			echo "--> Attempting to install terraform with yum packages"
			${sudo_command} yum install -y yum-utils
			${sudo_command} yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
			${sudo_command} yum -y install terraform || {
				echo >&2 "--> terraform install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> terraform already installed"
		fi

	## zypper-based systems
	elif command -v zypper >/dev/null 2>&1; then
		echo "--> Checking system packages and installing any missing packages"
		ZYPPERPACKAGES=" \
			curl \
			python \
			tar \
			which \
			jq \
			openssl \
			"
		for package in $ZYPPERPACKAGES; do
			if ! rpm -q "$package" >/dev/null; then
				echo "--> Zypper installing $package"
				${sudo_command} zypper install -y "$package" || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			else
				echo "--> $package already installed"
			fi
		done
		if ! command -v gcloud >/dev/null 2>&1; then
			echo "--> Attempting to install Google Cloud SDK with zypper packages"
			${sudo_command} zypper install -y google-cloud-sdk || {
				echo >&2 "--> google-cloud-sdk install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> Google Cloud SDK already installed"
		fi
		if ! command -v kubectl >/dev/null 2>&1; then
			echo "--> Attempting to install kubectl with zypper packages"
			zypper ar -f https://download.opensuse.org/tumbleweed/repo/oss/ factory
			zypper install -y kubectl || {
				echo >&2 "--> kubectl install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> kubectl already installed"
		fi
		if ! command -v terraform >/dev/null 2>&1; then
			echo "--> Attempting to install terraform with zypper packages"
			${sudo_command} zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Leap_15.2 snappy
			${sudo_command} zypper --gpg-auto-import-keys refresh
			${sudo_command} zypper dup --from snappy
			${sudo_command} zypper install snapd
			${sudo_command} systemctl enable snapd
			${sudo_command} systemctl start snapd
			${sudo_command} systemctl enable snapd.apparmor
			${sudo_command} systemctl start snapd.apparmor
			${sudo_command} snap install terraform || {
				echo >&2 "--> terraform install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> terraform already installed"
		fi

		## pacman-based systems
	elif command -v pacman >/dev/null 2>&1; then
		echo "--> Checking system packages and installing any missing packages"
		PACMANPACKAGES=" \
			curl \
			python \
			tar \
			which \
			jq \
			gcc \
			awk \
			grep \
			openssl \
			kubectl \
			unzip \
			"

		for package in $PACMANPACKAGES; do
			if ! pacman -Q "$package" 2>/dev/null; then
				echo "--> pacman installing $package"
				${sudo_command} pacman -Sy --noconfirm "$package" || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			else
				echo "--> $package already installed"
			fi
		done
		if ! command -v gcloud >/dev/null 2>&1; then
			echo "--> Attempting to install Google Cloud SDK with curl"
			curl -LO https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz
			tar -xzf google-cloud-sdk.tar.gz
			./google-cloud-sdk/install.sh || {
				echo >&2 "--> Google Cloud SDK install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> Google Cloud SDK already installed"
		fi
		echo "--> Attempting to install terraform with curl"
		if ! command -v terraform >/dev/null 2>&1; then
			curl -LO https://releases.hashicorp.com/terraform/1.1.0/terraform_1.1.0_linux_arm64.zip
			unzip terraform_1.1.0_linux_arm64.zip
			${sudo_command} mv terraform /usr/local/bin/
			terraform -help || {
				echo >&2 "--> terraform install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> terraform already installed"
		fi

	## Mystery linux system without any of our recognised package managers
	else
		command -v curl >/dev/null 2>&1 || {
			echo >&2 "curl not found; please install and re-run this script."
			exit 1
		}
		command -v awk >/dev/null 2>&1 || {
			echo >&2 "awk not found; please install and re-run this script."
			exit 1
		}
		command -v grep >/dev/null 2>&1 || {
			echo >&2 "grep not found; please install and re-run this script."
			exit 1
		}
		command -v python >/dev/null 2>&1 || {
			echo >&2 "python not found; please install and re-run this script."
			exit 1
		}
		command -v jq >/dev/null 2>&1 || {
			echo >&2 "jq not found; please install and re-run this script."
			exit 1
		}
		echo "--> Attempting to install Google Cloud SDK with curl"
		if ! command -v gcloud >/dev/null 2>&1; then
			curl -LO https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz
			tar -xzf google-cloud-sdk.tar.gz
			./google-cloud-sdk/install.sh || {
				echo >&2 "--> Google Cloud SDK install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> Google Cloud SDK already installed"
		fi
		echo "--> Attempting to install kubectl with curl"
		if ! command -v kubectl >/dev/null 2>&1; then
			curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || {
				echo >&2 "--> kubectl download failed; please install manually and re-run this script."
				exit 1
			}
			chmod +x ./kubectl
			${sudo_command} mv ./kubectl /usr/local/bin/kubectl
		else
			echo "--> kubectl already installed"
		fi
		echo "--> Attempting to install terraform with curl"
		if ! command -v terraform >/dev/null 2>&1; then
			curl -LO https://releases.hashicorp.com/terraform/1.1.0/terraform_1.1.0_linux_arm64.zip
			unzip terraform_1.1.0_linux_arm64.zip
			${sudo_command} mv terraform /usr/local/bin/
			terraform -help || {
				echo >&2 "--> terraform install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> terraform already installed"
		fi
	fi

	## Helm isn't well packaged for Linux, alas
	command -v curl >/dev/null 2>&1 || {
		echo >&2 "curl not found; please install and re-run this script."
		exit 1
	}
	command -v awk >/dev/null 2>&1 || {
		echo >&2 "awk not found; please install and re-run this script."
		exit 1
	}
	command -v grep >/dev/null 2>&1 || {
		echo >&2 "grep not found; please install and re-run this script."
		exit 1
	}
	command -v python >/dev/null 2>&1 || {
		echo >&2 "python not found; please install and re-run this script."
		exit 1
	}
	command -v tar >/dev/null 2>&1 || {
		echo >&2 "tar not found; please install and re-run this script."
		exit 1
	}
	command -v which >/dev/null 2>&1 || {
		echo >&2 "which not found; please install and re-run this script."
		exit 1
	}
	echo "--> Helm doesn't have a system package; attempting to install with curl"
	curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
	chmod 700 get_helm.sh
	./get_helm.sh || {
		echo >&2 "--> helm install failed; please install manually and re-run this script."
		exit 1
	}

## Installing on OS X
elif [[ ${OSTYPE} == 'darwin'* ]]; then
	echo "--> This is a MacOS build"
	if command -v brew >/dev/null 2>&1; then
		echo "--> Checking brew packages and installing any missing packages"
		BREWPACKAGES=" \
			curl \
			python \
			kubernetes-cli \
			helm \
			jq \
			"
		BREWCASKS=" \
			google-cloud-sdk \
			"

		brew update
		for package in $BREWPACKAGES; do
			if ! brew ls --versions "$package" >/dev/null; then
				echo "--> Brew installing $package"
				brew install "$package" || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			else
				echo "--> $package is already installed"
			fi
		done
		for package in $BREWCASKS; do
			if ! brew ls --cask --versions "$package" >/dev/null; then
				echo "--> Brew installing $package"
				brew install --cask "$package" || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			fi
		done
		if ! brew ls --versions terraform >/dev/null; then
			echo "--> Brew installing terraform"
			brew tap hashicorp/tap
			brew install hashicorp/tap/terraform || {
				echo >&2 "--> terraform install failed; please install manually and re-run this script."
				exit 1
			}
		fi
	else
		command -v curl >/dev/null 2>&1 || {
			echo >&2 "curl not found; please install and re-run this script."
			exit 1
		}
		command -v python >/dev/null 2>&1 || {
			echo >&2 "python not found; please install and re-run this script."
			exit 1
		}
		command -v tar >/dev/null 2>&1 || {
			echo >&2 "tar not found; please install and re-run this script."
			exit 1
		}
		command -v which >/dev/null 2>&1 || {
			echo >&2 "which not found; please install and re-run this script."
			exit 1
		}
		echo "--> Attempting to install Google Cloud SDK with curl"
		if ! command -v gcloud >/dev/null 2>&1; then
			curl -LO https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz
			tar -xzf google-cloud-sdk.tar.gz
			./google-cloud-sdk/install.sh || {
				echo >&2 "--> Google Cloud SDK install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> Google Cloud SDK already installed"
		fi
		echo "--> Attempting to install kubectl with curl"
		if ! command -v kubectl >/dev/null 2>&1; then
			curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || {
				echo >&2 "--> kubectl download failed; please install manually and re-run this script."
				exit 1
			}
			chmod +x ./kubectl
			${sudo_command} mv ./kubectl /usr/local/bin/kubectl
		else
			echo "--> kubectl already installed"
		fi
		echo "--> Attempting to install helm with curl"
		if ! command -v helm >/dev/null 2>&1; then
			curl -L https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
			chmod 700 get_helm.sh
			./get_helm.sh || {
				echo >&2 "--> helm install failed; please install manually and re-run this script."
				exit 1
			}
		fi
		echo "--> Attempting to install terraform with curl"
		if ! command -v terraform >/dev/null 2>&1; then
			curl -LO https://releases.hashicorp.com/terraform/1.1.0/terraform_1.1.0_linux_arm64.zip
			unzip terraform_1.1.0_linux_arm64.zip
			${sudo_command} mv terraform /usr/local/bin/
			terraform -help || {
				echo >&2 "--> terraform install failed; please install manually and re-run this script."
				exit 1
			}
		fi
	fi
else
	echo "--> This is a Windows build"
	## chocolatey-based systems
	if command -v choco >/dev/null 2>&1; then
		echo "--> Checking chocolatey packages and installing any missing packages"
		CHOCPACKAGES=" \
			curl \
			python \
			terraform \
			gcloudsdk \
			kubernetes-cli \
			kubernetes-helm \
			jq \
			"
		choco upgrade chocolatey -y
		for package in $CHOCPACKAGES; do
			if ! choco search --local-only "$package" >/dev/null; then
				echo "--> Choco installing $package"
				choco install "$package" || {
					echo >&2 "--> $package install failed; please install manually and re-run this script."
					exit 1
				}
			else
				echo "--> $package is already installed"
			fi
		done
	else
		command -v curl >/dev/null 2>&1 || {
			echo >&2 "curl not found; please install and re-run this script."
			exit 1
		}
		command -v python >/dev/null 2>&1 || {
			echo >&2 "python not found; please install and re-run this script."
			exit 1
		}
		command -v tar >/dev/null 2>&1 || {
			echo >&2 "tar not found; please install and re-run this script."
			exit 1
		}
		command -v which >/dev/null 2>&1 || {
			echo >&2 "which not found; please install and re-run this script."
			exit 1
		}
		echo "--> Attempting to install Azure-CLI with curl"
		if ! command -v az >/dev/null 2>&1; then
			curl -L https://aka.ms/InstallAzureCli | sh || {
				echo >&2 "--> Azure-CLI install failed; please install manually and re-run this script."
				exit 1
			}
		else
			echo "--> Azure-CLI already installed"
		fi
		echo "--> Attempting to install kubectl with curl"
		if ! command -v kubectl >/dev/null 2>&1; then
			curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || {
				echo >&2 "--> kubectl download failed; please install manually and re-run this script."
				exit 1
			}
			chmod +x ./kubectl
			${sudo_command} mv ./kubectl /usr/local/bin/kubectl
		else
			echo "--> kubectl already installed"
		fi
		echo "--> Attempting to install helm with curl"
		curl -s https://get.helm.sh/helm-v3.7.2-windows-amd64.tar.gz --output helm.tar.gz
		tar -xf ./helm.tar.gz
		${sudo_command} cp ./windows-amd64/helm /usr/local/bin/helm
	fi
fi
