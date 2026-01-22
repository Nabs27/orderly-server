# install flutter SDK (only once) and build web
set -euo pipefail

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"
flutter --version
flutter precache
flutter build web
