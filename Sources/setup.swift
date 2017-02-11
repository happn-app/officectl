import Guaka

// Generated, dont update
func setupCommands() {
	rootCommand.add(subCommand: backupCommand)
	backupCommand.add(subCommand: backupMailCommand)
  // Command adding placeholder, edit this line.
}
