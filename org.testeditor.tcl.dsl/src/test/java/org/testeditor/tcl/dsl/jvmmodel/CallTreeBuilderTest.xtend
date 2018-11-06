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
			head.treeId.assertEquals('ID-0')
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
			head.displayname.assertEquals('Cleanup')
			head.treeId.assertEquals('IDC-0')
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
			head.displayname.assertEquals('Setup')
			head.treeId.assertEquals('IDS-0')
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
			get(0).displayname.assertEquals('Setup')
			get(0).treeId.assertEquals('IDS-0')
			get(1).displayname.assertEquals('My first test step')
			get(1).treeId.assertEquals('ID-0')
			get(2).displayname.assertEquals('Cleanup')
			get(2).treeId.assertEquals('IDC-0')
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
			treeId = 'ID-2'
			children.assertSingleElement => [
				displayname.assertEquals(macros.macros.head.name)
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					children.assertSingleElement => [
						displayname.assertEquals('myVar = Read jsonObject from <bar> [com.google.gson.JsonObject]')
						treeId.assertEquals('ID-2-2')
					]
				]
			]
		]
		actualTree.children.assertSingleElement.children.last => [
			displayname.assertEquals(amlComponentForTesting.name)
			treeId.assertEquals('ID-3')
			children.assertSingleElement => [
				displayname.assertEquals('next step')
				treeId.assertEquals('ID-4')
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
			head.displayname.assertEquals('Setup')
			head.treeId.assertEquals('IDS-0')
			last.displayname.assertEquals('Cleanup')
			last.treeId.assertEquals('IDC-0')
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
				displayname.assertEquals('Setup')
				treeId.assertEquals('IDS-0')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('IDS-1')
					children.assertSingleElement => [
						displayname.assertEquals('Global Setup')
						treeId.assertEquals('IDS-2')
					]
				]
			]
			get(1) => [
				displayname.assertEquals('Setup')
				treeId.assertEquals('IDS-3')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('IDS-4')
					children.assertSingleElement => [
						displayname.assertEquals('Local Setup')
						treeId.assertEquals('IDS-5')
					]
				]
			]
			get(2) => [
				displayname.assertEquals('Cleanup')
				treeId.assertEquals('IDC-0')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('IDC-1')
					children.assertSingleElement => [
						displayname.assertEquals('Local Cleanup')
						treeId.assertEquals('IDC-2')
					]
				]
			]
			last => [
				displayname.assertEquals('Cleanup')
				treeId.assertEquals('IDC-3')
				children.assertSingleElement => [
					displayname.assertEquals(amlComponentForTesting.name)
					treeId.assertEquals('IDC-4')
					children.assertSingleElement => [
						displayname.assertEquals('Global Cleanup')
						treeId.assertEquals('IDC-5')
					]
				]
			]
		]
	}

}
