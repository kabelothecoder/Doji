import 'package:flutter/widgets.dart';

import 'platform_info.dart';

/// Width from which screens switch to their wide (desktop) layout.
const double wideLayoutFrom = 900;

/// The plans rule, shared: Windows is always wide; elsewhere from
/// [wideLayoutFrom] logical pixels (tablets, landscape, resized windows).
bool isWideLayout(BuildContext context) =>
    PlatformInfo.isWindows || MediaQuery.sizeOf(context).width >= wideLayoutFrom;
