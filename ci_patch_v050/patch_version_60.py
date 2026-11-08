from pathlib import Path
import re,sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'videdit_project')
screen=root/'lib/features/editor/editor_screen.dart'
pub=root/'pubspec.yaml'
s=screen.read_text(encoding='utf-8')
marker='          Positioned.fill(child: _previewExpanded ? _previewPanel() : (wide ? _wideLayout() : _compactLayout())),'
if s.count(marker)!=1:raise RuntimeError('Version badge layout marker missing '+str(s.count(marker)))
addition='''          Positioned(
            right: 8,
            bottom: 4,
            child: IgnorePointer(
              child: Semantics(
                label: 'Versión 6.0',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .42),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Text(
                      'v6.0',
                      style: TextStyle(fontSize: 9, color: Colors.white70, height: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),'''
s=s.replace(marker,marker+'\n'+addition,1)
screen.write_text(s,encoding='utf-8')
p=pub.read_text(encoding='utf-8')
p,n=re.subn(r'(?m)^version:\s*\S+', 'version: 6.0.0+60',p,count=1)
if n!=1:raise RuntimeError('Pubspec version not found')
pub.write_text(p,encoding='utf-8')
print('Installed discrete non-interactive bottom-right v6.0 badge and internal 6.0.0+60 version.')
