/*
 * ActionErasure.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/06/2019.
 */

import Foundation



extension Action where SubjectType : Hashable {
	
	func eraseToAnyHashableSubject() -> AnyHashableErasedAction<ParametersType, ResultType> {
		return AnyHashableErasedAction<ParametersType, ResultType>(erasedAction: self)
	}
	
}


class AnyHashableErasedAction<ParametersType, ResultType> : Action<AnyHashable, ParametersType, ResultType> {
	
	var subAction: Action<AnyHashable, ParametersType, ResultType>
	
	init<Subject : Hashable>(erasedAction: Action<Subject, ParametersType, ResultType>) {
		super.init(subject: erasedAction.subject)
		subAction = erasedAction
	}
	
	public var isExecuting: Bool {
		return stateSyncQueue.sync{ currentState.isRunning }
	}
	
}
