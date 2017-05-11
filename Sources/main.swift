import Guaka

func setupCommands() {
	rootCommand.add(subCommand: backupCommand)
	rootCommand.add(subCommand: devtestCommand)
	rootCommand.add(subCommand: listusersCommand)
	rootCommand.add(subCommand: gettokenCommand)
	
	backupCommand.add(subCommand: backupMailCommand)
	
	devtestCommand.add(subCommand: devtestGmailapiCommand)
}

setupCommands()
rootCommand.execute()
