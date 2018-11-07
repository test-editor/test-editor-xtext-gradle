package org.testeditor.tcl.dsl.jvmmodel

import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.emf.ecore.EObject
import org.testeditor.tcl.AbstractTestStep
import org.testeditor.tcl.CallTreeNode
import org.testeditor.tcl.Macro
import org.testeditor.tcl.StepContainer
import org.testeditor.tcl.TestCase
import org.testeditor.tcl.TestStep
import org.testeditor.tcl.TestStepContext
import org.testeditor.tcl.dsl.messages.TclElementStringifier
import org.testeditor.tcl.impl.TclFactoryImpl
import org.testeditor.tcl.util.TclModelUtil

@Singleton
class CallTreeBuilder {

	static val testSetupDisplayName = 'setup'
	static val testCleanupDisplayName = 'cleanup'
	static val testConfigName = 'Config'
	static val testLocalName = 'Local'

	var String idPrefix = TclJvmModelInferrer.ID_PREFIX_TEST

	@Inject extension TclFactoryImpl tclFactory
	@Inject extension TclModelUtil
	@Inject extension TclElementStringifier

	def CallTreeNode buildCallTree(TestCase model) {
		return model.namedCallTreeNode => [
			val parentSetup = (model.config?.setup ?: #[])
			val parentCleanup = (model.config?.cleanup ?: #[])

			treeId = 'IDROOT'

			runningNumber = 0
			idPrefix = TclJvmModelInferrer.ID_PREFIX_CONFIG_SETUP
			if (!parentSetup.empty) {
				children += callTreeNodeNamed(#[testConfigName, testSetupDisplayName].join(' ')) => [
					children += parentSetup.flatMap[toCallTreeChildren]
				]
			}
			if (!model.setup.empty) {
				children += callTreeNodeNamed(#[testLocalName, testSetupDisplayName].join(' ')) => [
					children += model.setup.flatMap[toCallTreeChildren]
				]
			}
			
			runningNumber = 0
			idPrefix = TclJvmModelInferrer.ID_PREFIX_TEST
			children += model.steps.map[toCallTree]
			
			runningNumber = 0
			idPrefix = TclJvmModelInferrer.ID_PREFIX_CONFIG_CLEANUP
			if (!model.cleanup.empty) {
				children += callTreeNodeNamed(#[testLocalName, testCleanupDisplayName].join(' ')) => [
					children += model.cleanup.flatMap[toCallTreeChildren]
				]
			}

			if (!parentCleanup.empty) {
				children += callTreeNodeNamed(#[testConfigName, testCleanupDisplayName].join(' ')) => [
					children += parentCleanup.flatMap[toCallTreeChildren]
				]
			}
		]
	}

	def Iterable<CallTreeNode> toCallTreeChildren(StepContainer model) {
		return model.contexts.map[toCallTree]
	}

	def dispatch CallTreeNode toCallTree(StepContainer model) {
		return model.namedCallTreeNode => [
			children += model.contexts.map[toCallTree]
		]
	}

	def dispatch CallTreeNode toCallTree(TestStepContext model) {
		return model.namedCallTreeNode => [
			children += model.steps.map[toCallTree]
		]
	}

	def dispatch CallTreeNode toCallTree(AbstractTestStep model) {
		return model.namedCallTreeNode
	}
	
	long runningNumber = 0

	def dispatch CallTreeNode toCallTree(TestStep model) {
		val result = model.namedCallTreeNode
		result => [
			if (model.hasMacroContext) {
				val previousPrefix = idPrefix
				val previousRunningNumber = runningNumber
				idPrefix = result.treeId
				runningNumber = 0
				children += model.findMacro.toCallTree
				idPrefix = previousPrefix
				runningNumber = previousRunningNumber
			}
		]
		return result
	}
	
	def dispatch CallTreeNode toCallTree(Macro model) {
		return model.namedCallTreeNode => [
			children += model.contexts.map[toCallTree]
		]
	}

	def dispatch CallTreeNode toCallTree(EObject model) {
		return model.namedCallTreeNode
	}

	def namedCallTreeNode(EObject model) {
		return callTreeNodeNamed(model.stringify)
	}

	def callTreeNodeNamed(String name) {
		return createCallTreeNode => [
			displayname = name
			treeId = idPrefix + '-' + Long.toString(runningNumber)
			runningNumber++
		]
	}

}
