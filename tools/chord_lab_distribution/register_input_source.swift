import Carbon
import Foundation

guard CommandLine.arguments.count == 2 else {
  fputs("Expected the installed GureumChordLab.app path.\n", stderr)
  exit(2)
}
let app = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let expected = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Input Methods/GureumChordLab.app").standardizedFileURL
guard app == expected,
  Bundle(url: app)?.bundleIdentifier == "io.github.kathar0s.inputmethod.GureumChordLab"
else {
  fputs("Refusing to register an unexpected app path or identity.\n", stderr)
  exit(2)
}
let status = TISRegisterInputSource(app as CFURL)
print("Lab 입력기 등록: OSStatus \(status)")
exit(status == noErr ? 0 : 1)
