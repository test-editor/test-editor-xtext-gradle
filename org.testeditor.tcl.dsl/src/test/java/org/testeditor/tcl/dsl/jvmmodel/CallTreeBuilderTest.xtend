package org.testeditor.tcl.dsl.jvmmodel

import javax.inject.Inject
import org.junit.Before
import org.junit.Test
import org.testeditor.aml.AmlModel
import org.testeditor.aml.Component
import org.testeditor.aml.dsl.tests.AmlModelGenerator
import org.testeditor.dsl.common.testing.DslParseHelper
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.tcl.dsl.tests.AbstractTclTest
import org.testeditor.tcl.dsl.tests.TclModelGenerator
import org.testeditor.tcl.impl.TclFactoryImpl

class CallTreeBuilderTest extends AbstractTclTest {

	@Inject extension DslParseHelper parserHelper
	@Inject extension TclModelGenerator tclModelGenerator
	@Inject extension AmlModelGenerator
	@Inject extension TclFactoryImpl tclFactory
	@Inject CallTreeBuilder builderUnderTest

	AmlModel amlModelForTesting
	Component amlComponentForTesting

	@Before
	def void setupAmlAndDummyFixture() {
		amlModelForTesting = parseAml(DummyFixture.amlModel)
		amlComponentForTesting = amlModelForTesting.components.findFirst[name == "GreetingApplication"]
	}

	@Test
	def void returnsSingleCallTreeNodeForEmptyTestCase() {
		// given
		val testCase = testCase('TheTestCase')

		// when
		val actualNode = builderUnderTest.buildCallTree(testCase)

		// then
		actualNode.displayname.assertEquals('TheTestCase')
		actualNode.treeId.assertEquals('IDROOT')
		actualNode.children.assertEmpty
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithSpecificationStepImplementations() {
		// given
		val testCase = testCase('TheTestCase') => [
			steps += specificationStep('My', 'first', 'test', 'step')
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.displayname.assertEquals('TheTestCase')
		actualTree.children => [
			assertSize(1)
			head.displayname.assertEquals('My first test step')
			head.treeId.assertEquals('ID-1-0')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithCleanup() {
		// given
		val testCase = testCase('TheTestCase') => [
			cleanup += createTestCleanup
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children => [
			assertSize(1)
			head.displayname.assertEquals('Local cleanup')
			head.treeId.assertEquals('ID-2-0')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithSetup() {
		// given
		val testCase = testCase('TheTestCase') => [
			setup += createTestSetup
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children => [
			assertSize(1)
			head.displayname.assertEquals('Local setup')
			head.treeId.assertEquals('ID-0-0')
		]
	}

	/**
	 * Under a test case, setup always comes first, then the test steps, then the cleanup.
	 */
	@Test
	def void returnsCallTreeWithProperlyOrderedSubElements() {
		// given
		val testCase = testCase('TheTestCase') => [
			setup += createTestSetup
			steps += specificationStep('My', 'first', 'test', 'step')
			cleanup += createTestCleanup
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children => [
			assertSize(3)
			get(0).displayname.assertEquals('Local setup')
			get(0).treeId.assertEquals('ID-0-0')
			get(1).displayname.assertEquals('My first test step')
			get(1).treeId.assertEquals('ID-1-0')
			get(2).displayname.assertEquals('Local cleanup')
			get(2).treeId.assertEquals('ID-2-0')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithComponentContext() {
		// given
		val testCase = testCase('TheTestCase') => [
			steps += specificationStep('My', 'first', 'test', 'step') => [
				contexts += componentTestStepContext(amlComponentForTesting)
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children.head.children => [
			assertSize(1)
			head.displayname.assertEquals(amlComponentForTesting.name)
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithMacroContext() {
		// given		
		val testCase = testCase('TheTestCase') => [
			steps += specificationStep('My', 'first', 'test', 'step') => [
				contexts += macroTestStepContext(macroCollection('MyMacroCollection'))
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children.head.children => [
			assertSize(1)
			head.displayname.assertEquals('MyMacroCollection')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithTestStepsInComponentContext() {
		// given
		val testCase = testCase('TheTestCase') => [
			steps += specificationStep('My', 'first', 'test', 'step') => [
				contexts += componentTestStepContext(amlComponentForTesting) => [
					steps += testStep('Wait', 'for').withParameter('60').withText('seconds')
				]
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children.head.children.head.children => [
			assertSize(1)
			head.displayname.assertEquals('Wait for "60" seconds')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithTestStepWithAssignment() {
		// given
		val testCase = testCase('TheTestCase') => [
			steps += specificationStep('My', 'first', 'test', 'step') => [
				contexts += componentTestStepContext(amlComponentForTesting) => [
					steps += testStepWithAssignment('myVar', 'Read', 'jsonObject', 'from').withElement('bar')
				]
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children.head.children.head.children => [
			assertSize(1)
			head.displayname.assertEquals('myVar = Read jsonObject from <bar> [com.google.gson.JsonObject]')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithAssertionTestStep() {
		// given
		val tclModel = '''
			package com.example
			# TheTestCase
			* My first test step
				Component: GreetingApplication
				- isVisible = Is <bar> visible?
				- assert isVisible
		'''.toString.parseTcl('TheTestCase.tcl')

		// when
		val actualTree = builderUnderTest.buildCallTree(tclModel.test)

		// then
		actualTree.children.head.children.head.children => [
			assertSize(2)
			last.displayname.assertEquals('assert isVisible')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithAssignmentThroughPath() {
		// given
		val tclModel = '''
			package com.example
			# TheTestCase
			* My first test step
				Component: GreetingApplication
				- obj = Read jsonObject from <bar>
				- obj."key"[42] = 1 = 2
		'''.toString.parseTcl('TheTestCase.tcl')

		// when
		val actualTree = builderUnderTest.buildCallTree(tclModel.test)

		// then
		actualTree.children.head.children.head.children => [
			assertSize(2)
			last.displayname.assertEquals('obj."key"[42] = 1 = 2')
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithTestStepsInMacroContext() {
		// given
		val macros = macroCollection('MyMacros') => [
			macros += macro('macro1') => [
				val templateVar = templateVariable('param')
				template = template("read").withParameter(templateVar)
				contexts += componentTestStepContext(amlComponentForTesting) => [
					steps += testStepWithAssignment('myVar', 'Read', 'jsonObject', 'from').withElement('bar')
				]

			]
		]
		val tclModel = tclModel => [
			macroCollection = macros
			test = testCase('TheTestCase') => [
				steps += specificationStep('My', 'first', 'test', 'step') => [
					contexts += macroTestStepContext(macros) => [
						steps += testStep('read').withParameter('bar')
					]
					contexts += componentTestStepContext(amlComponentForTesting) => [
						steps += testStep('next', 'step')
					]
				]
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(tclModel.test)

		// then
		actualTree.children.head.children.head.children.assertSingleElement => [
			displayname.assertEquals('read "bar"')
			treeId.assertEquals('ID-1-2')
			children.assertSingleElement => [
				displayname.assertEquals(macros.macros.head.name)
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					children.assertSingleElement => [
						displayname.assertEquals('myVar = Read jsonObject from <bar> [com.google.gson.JsonObject]')
						treeId.assertEquals('ID-1-2-2')
					]
				]
			]
		]
		actualTree.children.assertSingleElement.children.last => [
			displayname.assertEquals(amlComponentForTesting.name)
			treeId.assertEquals('ID-1-3')
			children.assertSingleElement => [
				displayname.assertEquals('next step')
				treeId.assertEquals('ID-1-4')
			]
		]
	}

	@Test
	def void returnsProperCallTreeForTestCaseWithNonEmptyConfig() {
		// given
		val testCase = testCase('TheTestCase') => [
			config = testConfig('myConfig') => [
				setup += createTestSetup
				cleanup += createTestCleanup
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children => [
			assertSize(2)
			head.displayname.assertEquals('Config setup')
			head.treeId.assertEquals('ID-0-0')
			last.displayname.assertEquals('Config cleanup')
			last.treeId.assertEquals('ID-2-0')
		]
	}

	@Test
	def void ignoresEmptyTestConfiguration() {
		// given
		val testCase = testCase('TheTestCase') => [
			config = testConfig('myConfig')
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children.assertEmpty
	}

	@Test
	def void putsConfiguredAndLocalSetupAndCleanupInCorrectOrder() {
		// given
		val testCase = testCase('TheTestCase') => [
			config = testConfig('myConfig') => [
				setup += createTestSetup => [
					contexts += componentTestStepContext(amlComponentForTesting) => [
						steps += testStep('Global', 'Setup')
					]
				]
				cleanup += createTestCleanup => [
					contexts += componentTestStepContext(amlComponentForTesting) => [
						steps += testStep('Global', 'Cleanup')
					]
				]
			]
			setup += createTestSetup => [
				contexts += componentTestStepContext(amlComponentForTesting) => [
					steps += testStep('Local', 'Setup')
				]
			]
			cleanup += createTestCleanup => [
				contexts += componentTestStepContext(amlComponentForTesting) => [
					steps += testStep('Local', 'Cleanup')
				]
			]
		]

		// when
		val actualTree = builderUnderTest.buildCallTree(testCase)

		// then
		actualTree.children => [
			assertSize(4)
			head => [
				displayname.assertEquals('Config setup')
				treeId.assertEquals('ID-0-0')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('ID-0-1')
					children.assertSingleElement => [
						displayname.assertEquals('Global Setup')
						treeId.assertEquals('ID-0-2')
					]
				]
			]
			get(1) => [
				displayname.assertEquals('Local setup')
				treeId.assertEquals('ID-0-3')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('ID-0-4')
					children.assertSingleElement => [
						displayname.assertEquals('Local Setup')
						treeId.assertEquals('ID-0-5')
					]
				]
			]
			get(2) => [
				displayname.assertEquals('Local cleanup')
				treeId.assertEquals('ID-2-0')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('ID-2-1')
					children.assertSingleElement => [
						displayname.assertEquals('Local Cleanup')
						treeId.assertEquals('ID-2-2')
					]
				]
			]
			last => [
				displayname.assertEquals('Config cleanup')
				treeId.assertEquals('ID-2-3')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('ID-2-4')
					children.assertSingleElement => [
						displayname.assertEquals('Global Cleanup')
						treeId.assertEquals('ID-2-5')
					]
				]
			]
		]
	}

}
