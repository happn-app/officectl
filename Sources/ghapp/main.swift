import Guaka

func setupCommands() {
	rootCommand.add(subCommand: backupCommand)
	rootCommand.add(subCommand: devtestCommand)
	rootCommand.add(subCommand: listusersCommand)
	rootCommand.add(subCommand: gettokenCommand)
	
	backupCommand.add(subCommand: backupMailCommand)
	
	devtestCommand.add(subCommand: devtestCurtestCommand)
	devtestCommand.add(subCommand: devtestGmailapiCommand)
	devtestCommand.add(subCommand: devtestGetstaffgroupsCommand)
	devtestCommand.add(subCommand: devtestGetexternalgroupsCommand)
	devtestCommand.add(subCommand: devtestGetgroupscontaininggroupsCommand)
}

setupCommands()
rootCommand.execute()
