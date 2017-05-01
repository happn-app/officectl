import Guaka

func setupCommands() {
	rootCommand.add(subCommand: backupCommand)
	backupCommand.add(subCommand: backupMailCommand)
}

setupCommands()
rootCommand.execute()
