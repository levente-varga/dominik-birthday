!include "MUI2.nsh"

SetCompressor /SOLID lzma
SetCompressorDictSize 32

Name "Dominik"
Caption "Dominik"
OutFile "..\Dominik.exe"
Icon "..\windows\runner\resources\app_icon.ico"
SilentInstall silent
RequestExecutionLevel user

Section
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  File /r "..\build\windows\x64\runner\Release\*.*"
  ExecWait '"$PLUGINSDIR\dominik.exe"'
SectionEnd
