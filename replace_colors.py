import re
import sys
from pathlib import Path

FILES = [
    "lib/widgets/confirm_popup.dart",
    "lib/widgets/global_achievement_overlay.dart",
    "lib/widgets/menu_button.dart",
    "lib/widgets/token_receipt_widget.dart",
    "lib/widgets/run_timer_badge.dart",
    "lib/widgets/game_scaffold.dart",
    "lib/placeholder_game.dart",
]

base_dir = Path("/Users/leventevarga/Projects/Dominik/dominik")

MAPPINGS = {
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.04\)": "AppColors.surfHigh04",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.2\)": "AppColors.surfHigh20",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.3\)": "AppColors.surfHigh30",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.35\)": "AppColors.surfHigh35",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.4\)": "AppColors.surfHigh40",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.45\)": "Color.lerp(AppColors.surface, theme.colorScheme.surfaceContainerHighest, 0.45)!",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.5\)": "AppColors.surfHigh50",
    r"theme\.colorScheme\.surfaceContainerHighest\.withValues\(alpha:\s*0\.98\)": "AppColors.surfHigh98",
    
    r"theme\.colorScheme\.outline\.withValues\(alpha:\s*0\.12\)": "AppColors.outline12",
    r"theme\.colorScheme\.outline\.withValues\(alpha:\s*0\.15\)": "AppColors.outline15",
    r"theme\.colorScheme\.outline\.withValues\(alpha:\s*0\.2\)": "AppColors.outline20",
    r"theme\.colorScheme\.outline\.withValues\(alpha:\s*0\.25\)": "AppColors.outline25",
    r"theme\.colorScheme\.outline\.withValues\(alpha:\s*0\.3\)": "AppColors.outline30",
    r"theme\.colorScheme\.outline\.withValues\(alpha:\s*0\.4\)": "AppColors.outline40",
    
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.2\)": "AppColors.onSurf20",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.25\)": "AppColors.onSurf25",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.3\)": "AppColors.onSurf30",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.35\)": "AppColors.onSurf35",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.4\)": "AppColors.onSurf40",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.5\)": "AppColors.onSurf50",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.6\)": "AppColors.onSurf60",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.7\)": "AppColors.onSurf70",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.8\)": "AppColors.onSurf80",
    r"theme\.colorScheme\.onSurface\.withValues\(alpha:\s*0\.85\)": "AppColors.onSurf85",

    r"theme\.colorScheme\.primary\.withValues\(alpha:\s*0\.1\)": "AppColors.primary10",
    r"theme\.colorScheme\.primary\.withValues\(alpha:\s*0\.15\)": "AppColors.primary15",
    r"theme\.colorScheme\.primary\.withValues\(alpha:\s*0\.35\)": "AppColors.primary35",
    r"theme\.colorScheme\.primary\.withValues\(alpha:\s*0\.4\)": "AppColors.primary40",
    r"theme\.colorScheme\.primary\.withValues\(alpha:\s*0\.5\)": "AppColors.primary50",
    
    r"theme\.colorScheme\.primaryContainer\.withValues\(alpha:\s*0\.2\)": "AppColors.primaryCont20",
    r"theme\.colorScheme\.secondary\.withValues\(alpha:\s*0\.5\)": "AppColors.secondary50",
    r"theme\.colorScheme\.secondaryContainer\.withValues\(alpha:\s*0\.6\)": "AppColors.secContainer60",
    r"theme\.colorScheme\.error\.withValues\(alpha:\s*0\.3\)": "AppColors.error30",
    r"theme\.colorScheme\.errorContainer\.withValues\(alpha:\s*0\.4\)": "AppColors.errContainer40",
    r"theme\.colorScheme\.errorContainer\.withValues\(alpha:\s*0\.6\)": "AppColors.errContainer60",

    r"Colors\.green\.withValues\(alpha:\s*0\.15\)": "AppColors.green15",
    r"Colors\.green\.withValues\(alpha:\s*0\.2\)": "AppColors.green20",
    r"Colors\.green\.withValues\(alpha:\s*0\.25\)": "AppColors.green25",
    r"Colors\.green\.withValues\(alpha:\s*0\.3\)": "AppColors.green30",
    r"Colors\.green\.withValues\(alpha:\s*0\.35\)": "AppColors.green35",
    r"Colors\.green\.withValues\(alpha:\s*0\.4\)": "AppColors.green40",
    r"Colors\.green\.withValues\(alpha:\s*0\.85\)": "AppColors.green85",

    r"Colors\.red\.withValues\(alpha:\s*0\.2\)": "AppColors.red20",
    r"Colors\.red\.withValues\(alpha:\s*0\.3\)": "AppColors.red30",
    r"Colors\.red\.withValues\(alpha:\s*0\.35\)": "AppColors.red35",

    r"Colors\.amber\.withValues\(alpha:\s*0\.15\)": "AppColors.amber15",
    r"Colors\.amber\.withValues\(alpha:\s*0\.3\)": "AppColors.amber30",
    r"Colors\.amber\.withValues\(alpha:\s*0\.35\)": "AppColors.amber35",
    r"Colors\.amber\.withValues\(alpha:\s*0\.4\)": "AppColors.amber40",
    r"Colors\.amber\.withValues\(alpha:\s*0\.5\)": "AppColors.amber50",
    r"Colors\.amber\.withValues\(alpha:\s*0\.6\)": "AppColors.amber60",

    r"Colors\.amber\.shade200\.withValues\(alpha:\s*0\.12\)": "AppColors.amber200_12",
    r"Colors\.amber\.shade300\.withValues\(alpha:\s*0\.4\)": "AppColors.amber300_40",
    r"Colors\.amberAccent\.withValues\(alpha:\s*0\.8\)": "AppColors.amberAccent80",

    r"Colors\.white\.withValues\(alpha:\s*0\.04\)": "AppColors.white04",
    r"Colors\.white\.withValues\(alpha:\s*0\.06\)": "AppColors.white06",
    r"Colors\.white\.withValues\(alpha:\s*0\.25\)": "AppColors.white25",
    r"Colors\.white\.withValues\(alpha:\s*0\.4\)": "AppColors.white40",
    r"Colors\.white\.withValues\(alpha:\s*0\.5\)": "AppColors.white50",

    r"Colors\.black\.withValues\(alpha:\s*0\.25\)": "AppColors.black25",
    r"Colors\.black\.withValues\(alpha:\s*0\.4\)": "AppColors.black40",
    r"Colors\.black\.withValues\(alpha:\s*0\.5\)": "AppColors.black50",
    r"Colors\.black\.withValues\(alpha:\s*0\.55\)": "AppColors.black55",
    r"Colors\.black\.withValues\(alpha:\s*0\.6\)": "AppColors.black60",
    r"Colors\.black\.withValues\(alpha:\s*0\.65\)": "AppColors.black65",
    r"Colors\.black\.withValues\(alpha:\s*0\.8\)": "AppColors.black80",

    r"Colors\.purpleAccent\.withValues\(alpha:\s*0\.6\)": "AppColors.purpleAccent60",
    r"Colors\.grey\.shade700\.withValues\(alpha:\s*0\.4\)": "AppColors.grey700_40",
    r"Colors\.grey\.shade700\.withValues\(alpha:\s*0\.9\)": "AppColors.grey700_90",
    r"Colors\.grey\.shade800\.withValues\(alpha:\s*0\.45\)": "AppColors.grey800_45",
    r"Colors\.grey\.shade900\.withValues\(alpha:\s*0\.7\)": "AppColors.grey900_70",
    r"Colors\.pink\.shade400\.withValues\(alpha:\s*0\.4\)": "AppColors.pink400_40",
    r"Colors\.pink\.shade400\.withValues\(alpha:\s*0\.45\)": "AppColors.pink400_45",
    r"Colors\.cyan\.shade300\.withValues\(alpha:\s*0\.9\)": "AppColors.cyan300_90",

    r"Colors\.transparent": "AppColors.surface",
}

for file_path in FILES:
    full_path = base_dir / file_path
    if not full_path.exists():
        print(f"Not found: {full_path}")
        continue
    content = full_path.read_text()
    
    original = content
    
    # 1. Exact matches
    for pat, rep in MAPPINGS.items():
        content = re.sub(pat, rep, content)
        
    # 2. Variable or unmapped static matches
    def lerp_replacer(m):
        base_color = m.group(1)
        alpha = m.group(2)
        return f"Color.lerp(AppColors.surface, {base_color}, {alpha})!"
    
    content = re.sub(r"([a-zA-Z0-9_\.]+)\.withValues\(alpha:\s*([0-9\.]+)\)", lerp_replacer, content)
    
    if content != original:
        if 'constants/colors.dart' not in content:
            import_statement = "import '../constants/colors.dart';\n"
            if file_path == "lib/placeholder_game.dart":
                import_statement = "import 'constants/colors.dart';\n"
            content = re.sub(r"(import 'package:flutter/material\.dart';\n)", r"\1" + import_statement, content)
        
        full_path.write_text(content)
        print(f"Updated {file_path}")
