package org.testeditor.tcl.dsl.validation

import javax.inject.Inject
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Test
import org.testeditor.tcl.dsl.tests.TclModelGenerator
import org.testeditor.tcl.dsl.tests.parser.AbstractParserTestWithDummyComponent

import static org.testeditor.tcl.TclPackage.Literals.*

class TclVarUsageValidatorTest extends AbstractParserTestWithDummyComponent {
	
	@Inject protected TclValidator tclValidator // class under test (not mocked)
	@Inject protected ValidationTestHelper validator
	@Inject extension TclModelGenerator

	@Test
	def void testForMultipleAssignments() {
		// given, when				
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
						// multiple declarations are illegal
						steps += testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')

		// then		
		tclModel.assertError(TEST_STEP, TclValidator.VARIABLE_ASSIGNED_MORE_THAN_ONCE)
	}

	@Test
	def void testForMultipleAssignmentsInDifferentMacros() {
		val tclModel = tclModel => [
			macroCollection = macroCollection() => [
				macros += macro("macro") => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
					]
				]
				macros += macro("macro2") => [
					contexts += componentTestStepContext(dummyComponent) => [
						// declaration is valid, since the new macro opens a new scope => different variable (same name) is declared   
						steps += testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tml')

		// then		
		tclModel.assertNoErrors 
	}

	@Test
	def void testVariableMapAccess() {		
		// given, when				
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						val assignmentStep=testStepWithAssignment("myVar", "getJsonObject").withElement("dummyElement")
						steps += assignmentStep
						steps += testStep("start") => [
							// variable map access is valid: declared first, usage within same test case, type of variable is Map
							contents += variableReferencePathAccess(assignmentStep.variable)
						]
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		tclModel.assertNoErrors
	}
	
	@Test
	def void testVariableMapAccessInAssignment() {
		// given, when
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						val assignmentStep=testStepWithAssignment("myVar", "getJsonObject").withElement("dummyElement")
						steps += assignmentStep
						steps += assignmentThroughPath(assignmentStep.variable, "key") => [
							expression = jsonString("value")
						]
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		// assignment to a json dereferenced with a key is allowed (results in a put)
		tclModel.assertNoErrors
	}
	
	@Test
	def void testVariableUsage() {
		// given, when				
		val assignmentStep=testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += assignmentStep
						// variable access is valid: declared first, usage within same test case
						steps += testStep("start").withReferenceToVariable(assignmentStep.variable)
					]
					contexts += componentTestStepContext(dummyComponent) => [
						// variable access is valid: declared first, usage within same test case
						steps += testStep("start").withReferenceToVariable(assignmentStep.variable)
					]
				]
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						// variable access is valid: declared first, usage within same test case
						steps += testStep("start").withReferenceToVariable(assignmentStep.variable)
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		tclModel.assertNoErrors
	}
	
	@Test
	def void testDataParameterUsage() {
		// given, when
		val dataBlock = testData('param1', 'param2')
		val tclModel = tclModel => [
			test = testCase => [
				data += dataBlock
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						// variable access is valid: declared first, usage within same test case
						steps += testStep("start").withReferenceToVariable(dataBlock.parameters.head)
						steps += testStep("start").withReferenceToVariable(dataBlock.parameters.last)
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		tclModel.assertNoErrors
	}

	@Test
	def void testVarUsageFromOtherContextSameMacro() {
		val assignmentStep = testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
		val tclModel = tclModel => [
			macroCollection = macroCollection() => [
				macros += macro("macro") => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += assignmentStep
					]
					contexts += componentTestStepContext(dummyComponent) => [
						// var access is valid: declared first, used within same macro
						steps += testStep("start").withReferenceToVariable(assignmentStep.variable)
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tml')

		// then
		tclModel.assertNoErrors
	}

	@Test
	def void testIllegalVarUsageFromOtherMacro() {
		val assignmentStep = testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
		val tclModel = tclModel => [
			macroCollection = macroCollection() => [
				macros += macro("macro") => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += assignmentStep
					]
				]
				macros += macro("macro2") => [
					contexts += componentTestStepContext(dummyComponent) => [
						// variable access is illegal, since variable is declared within different macro 
						steps += testStep("start").withReferenceToVariable(assignmentStep.variable)
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tml')

		// then
		tclModel.assertError(TEST_STEP, TclValidator.INVALID_VAR_DEREF)

	}

	@Test
	def void testVariableAccessInAssertion() {
		// given
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						val assignmentStep = testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
						steps += assignmentStep
						steps += assertionTestStep => [
							assertExpression = compareOnEquality(flatReference(assignmentStep.variable), "expected-value")
						]
					]
				]
			]
			addToResourceSet('Test.tcl')
		]

		// when + then
		tclModel.assertNoErrors
	}

	@Test
	def void testIllegalVariableMapAccessInAssertion() {		
		// given, when				
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						val assignmentStep=testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
						steps += assignmentStep
						steps += assertionTestStep => [
							// map access is illegal, since variable is of type String
							assertExpression = compareOnEquality(variableReferencePathAccess(assignmentStep.variable) => [ path += keyPathElement => [ key = "some" ] ], "expected-value")
						]
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		tclModel.assertError(COMPARISON, TclValidator.INVALID_JSON_ACCESS)
	}

	@Test
	def void testIllegalVariableMapAccess() {		
		// given, when				
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						val assignmentStep=testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
						steps += assignmentStep
						steps += testStep("start") => [
							// map access is illegal, since variable is of type String
							contents += variableReferencePathAccess(assignmentStep.variable) => [ path += keyPathElement => [ key = "some" ] ]
						]
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		tclModel.assertError(TEST_STEP, TclValidator.INVALID_JSON_ACCESS)
	}

	@Test
	def void testUsageFromOtherContextSameTestCase() {		
		// given, when				
		val assignmentStep=testStepWithAssignment("myVar", "getValue").withElement("dummyElement")
		val tclModel = tclModel => [
			test = testCase => [
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += assignmentStep
					]
				]
				steps += specificationStep => [
					contexts += componentTestStepContext(dummyComponent) => [
						steps += testStep("start").withReferenceToVariable(assignmentStep.variable)
					]
				]
			]
		]
		tclModel.addToResourceSet('Test.tcl')
		
		// then
		tclModel.assertNoErrors
	}

}
