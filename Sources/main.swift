import Guaka

func setupCommands() {
	rootCommand.add(subCommand: backupCommand)
	rootCommand.add(subCommand: devtestCommand)
	
	backupCommand.add(subCommand: backupMailCommand)
	
	devtestCommand.add(subCommand: devtestGmailapiCommand)
}

setupCommands()
rootCommand.execute()
