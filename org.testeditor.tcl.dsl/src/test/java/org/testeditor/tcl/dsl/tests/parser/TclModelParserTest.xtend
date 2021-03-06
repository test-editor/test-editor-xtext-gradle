/*******************************************************************************
 * Copyright (c) 2012 - 2018 Signal Iduna Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 * Signal Iduna Corporation - initial API and implementation
 * akquinet AG
 * itemis AG
 *******************************************************************************/
package org.testeditor.tcl.dsl.tests.parser

import javax.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.resource.XtextResource
import org.junit.Test
import org.testeditor.aml.TemplateText
import org.testeditor.aml.TemplateVariable
import org.testeditor.dsl.common.testing.DslParseHelper
import org.testeditor.tcl.AssertionTestStep
import org.testeditor.tcl.ComparatorMatches
import org.testeditor.tcl.Comparison
import org.testeditor.tcl.ComponentTestStepContext
import org.testeditor.tcl.ExpressionReturnTestStep
import org.testeditor.tcl.JsonNumber
import org.testeditor.tcl.JsonString
import org.testeditor.tcl.MacroTestStepContext
import org.testeditor.tcl.NullOrBoolCheck
import org.testeditor.tcl.StepContentElement
import org.testeditor.tcl.TclPackage
import org.testeditor.tcl.TestStep
import org.testeditor.tcl.TestStepWithAssignment
import org.testeditor.tcl.VariableReference
import org.testeditor.tcl.dsl.naming.TclQualifiedNameProvider
import org.testeditor.tcl.dsl.tests.AbstractTclTest
import org.testeditor.tcl.util.TclModelUtil
import org.testeditor.tsl.StepContentVariable

import static extension org.eclipse.xtext.nodemodel.util.NodeModelUtils.*

class TclModelParserTest extends AbstractTclTest {
	
	@Inject extension DslParseHelper
	@Inject extension TclModelUtil
	@Inject TclQualifiedNameProvider _qualifiedNameProvider
	
	@Test
	def void parseMinimal() {
		// given
		val input = '''
			package com.example
		'''
		
		// when
		val model = parseTcl(input)
		
		// then
		model.package.assertEquals('com.example')
	}
	
	@Test
	def void parseMinimalTestCaseWithoutName() {
		// given
		val input = ''
		
		// when
		val model = parseTcl(input, "/home/project/src/test/java/com/example/MyTest.tcl")
		
		// then
		model => [
			assertNoSyntaxErrors
			package.assertNull // is derived (e.g. during generation)
			test.name.assertNull // is derived
			_qualifiedNameProvider.getFullyQualifiedName(model.test).toString.assertEquals('com.example.MyTest')
		]
	}

	@Test
	def void parseMinimalTestCase() {
		// given
		val input = '# MyTest'
		
		// when
		val model = parseTcl(input, "MyTest.tcl")
		
		// then
		model => [
			assertNoSyntaxErrors
			package.assertNull // is derived (e.g. during generation)
			test.name.assertEquals("MyTest")
		]
	}

	@Test
	def void parseSimpleSpecificationStep() {
		// given
		val input = '''
			package com.example
			
			# MyTest
			* Start the famous      greetings application.
		'''
		
		// when
		val tcl = parseTcl(input)
		
		// then
		tcl.test.name.assertEquals('MyTest')
		tcl.test.steps.assertSingleElement => [
			contents.restoreString.assertEquals('Start the famous greetings application .')
		]
	}
	
	@Test
	def void parseSpecificationStepWithVariable() {
		// given
		val input = '''
			package com.example
			
			# Test
			* send greetings "Hello World" to the world.
		'''
		
		// when
		val test = parseTcl(input).test
		
		// then
		test.steps.assertSingleElement => [
			contents.restoreString.assertEquals('send greetings "Hello World" to the world .')
			contents.get(2).assertInstanceOf(StepContentVariable) => [
				value.assertEquals('Hello World')
			]
		]		
	}
	
	@Test
	def void parseTestContextWithSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			* Start the famous greetings application
				Mask: GreetingsApplication
				- starte Anwendung "org.testeditor.swing.exammple.Greetings"
				- gebe in <Eingabefeld> den Wert "Hello World" ein
		'''
		
		// when
		val test = parseTcl(input).test
		
		// then
		test.steps.assertSingleElement => [
			contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext) => [
				val componentNode = findNodesForFeature(TclPackage.Literals.COMPONENT_TEST_STEP_CONTEXT__COMPONENT).assertSingleElement
				componentNode.text.trim.assertEquals('GreetingsApplication')
				steps.assertSize(2)
				steps.get(0).assertInstanceOf(TestStep) => [
					contents.restoreString.assertEquals('starte Anwendung "org.testeditor.swing.exammple.Greetings"')	
				]
				steps.get(1).assertInstanceOf(TestStep) => [
					contents.restoreString.assertEquals('gebe in <Eingabefeld> den Wert "Hello World" ein')
				]
			]
		]
	}
	
	@Test
	def void parseEmptyComponentElementReference() {
		// given
		val input = '''
			package com.example
			
			# Test
			* Dummy step
				Mask: Demo
				- <> < 	> <
				>
		'''
		
		// when
		val test = parseTcl(input).test
		
		// then
		test.steps.assertSingleElement.contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext) => [
			val emptyReferences = steps.assertSingleElement.assertInstanceOf(TestStep).contents.assertSize(3)
			emptyReferences.forEach[
				assertInstanceOf(StepContentElement) => [
					value.assertNull
				]
			]
		]
	}

	@Test
	def void parseTestStepWithQuestionMark() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			* Start
				Mask: Demo
				- Is Component visible?
		'''
		
		// when
		val test = parseTcl(input).assertNoSyntaxErrors.test
		
		// then
		test.steps.assertSingleElement => [
			contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext) => [
				steps.assertSingleElement.assertInstanceOf(TestStep) => [
					contents.restoreString.assertEquals('Is Component visible ?')
				]
			]
		]
	}
	
	@Test
	def void parseTestStepWithVariableAssignmentSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			* Start
				Mask: Demo
				- hello = Lese den Text von <Input>
		'''
		
		// when
		val test = parseTcl(input).test
		
		// then
		test.steps.assertSingleElement => [
			contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext) => [
				steps.assertSingleElement.assertInstanceOf(TestStepWithAssignment) => [
					variable.name.assertEquals('hello')
					contents.restoreString.assertEquals('Lese den Text von <Input>')
				]
			]
		]
	}

	@Test
	def void parseTestStepAssertionWOComparator() {
		// given
		val input = '''
			package com.example
			
			# Test
			* Start using some keywords like is matches does not match
			  Mask: Demo
			  - hello = some
			  - assert hello
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.steps.assertSingleElement => [
			contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext) => [
				steps.assertSize(2).get(1).assertInstanceOf(AssertionTestStep) => [
					assertExpression.assertInstanceOf(NullOrBoolCheck) => [
						isNegated.assertFalse
						variableReference.variable.name.assertEquals("hello")
					]
				]
			]
		]
	}
	
	@Test
	def void parseTslAllowedStepSyntax() {
		// given
		val input = '''
			package com.example
			
			# Test
			* Hier kann jetzt ÄÜÖ ß ä ü ö or any Unicode like µm fast alles, stehen, oder
			'''

		// when
		val test = parseTcl(input).test

		// then
		test.steps.assertSingleElement => [
			contents.restoreString.assertEquals('Hier kann jetzt ÄÜÖ ß ä ü ö or any Unicode like µm fast alles , stehen , oder')
		]
	}

	@Test
	def void parseTestStepAssertion() {
		// given
		val input = '''
			package com.example
			
			# Test
			* Start using some keywords like is matches does not match
			  Mask: Demo
			  - hello = some
			  - assert hello does    not match ".*AAABBB.*"
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.steps.assertSingleElement => [
			contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext) => [
				steps.assertSize(2).get(1).assertInstanceOf(AssertionTestStep) => [
					assertExpression.assertInstanceOf(Comparison) => [
						left.assertInstanceOf(VariableReference) => [variable.name.assertEquals("hello")]
						comparator.assertInstanceOf(ComparatorMatches) => [negated.assertTrue]
						right.assertInstanceOf(Comparison) => [
							left.assertInstanceOf(JsonString) => [value.assertEquals(".*AAABBB.*")]
							comparator.assertNull
						]
					]
				]
			]
		]
	}

	@Test
	def void parseMacroTestStep() {
		// given
		val input = '''
			package com.example

			# Test
			* Do some complex step
			  Macro: MyMacroFile
			  - template as execute with "param" a and "param2"
			  - second template
		'''

		// when
		val test = parseTcl(input).assertNoSyntaxErrors.test

		// then
		test.steps.assertSingleElement => [
			contexts.assertSingleElement.assertInstanceOf(MacroTestStepContext) => [
				steps.assertSize(2)
				steps.head.assertInstanceOf(TestStep) => [
					contents.restoreString.assertMatches('template as execute with "param" a and "param2"')
				]
				steps.last.assertInstanceOf(TestStep) => [
					contents.restoreString.assertMatches('second template')
				]
			]
		]
	}

	@Test
	def void parseWithMultiVariableDereference() {
		// given
		val input = '''
			package com.example

			# MyMacroCollection

			## MacroStartWith
			template = "start with" ${startparam}
			Component: MyComponent
			- put @startparam into <other>

			// uses macro defined above
			## MacroUseWith
			template = "use macro with" ${useparam}
			Macro: MyMacroCollection
			- start with @useparam
		'''

		// when
		val model = parseTcl(input).assertNoSyntaxErrors

		// then
		model.package.assertEquals('com.example')
	}
	
	@Test
	def void parseMacroWithReturnValue() {
		// given
		val input = '''
			package com.example

			# TestThatUsesMacroWithReturnValue

			* Test step
			Macro: MyMacroCollection
			- value = my first macro call
		'''

		// when
		val model = parseTcl(input).assertNoSyntaxErrors

		// then
		model.test.steps.assertSingleElement.contexts.assertSingleElement.assertInstanceOf(MacroTestStepContext)
		.steps.assertSingleElement.assertInstanceOf(TestStepWithAssignment) => [
			variable.name.assertEquals('value')
			contents.restoreString.assertEquals('my first macro call')
		]
	}
	
	@Test
	def void parseMacroWithReturnExpression() {
		// given
		val input = '''
			package org.testeditor
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "return variable with keyword"
			Component: AComponent
			- return 42
		'''

		// when
		val model = parseTcl(input).assertNoSyntaxErrors

		// then
		model.macroCollection.macros.assertSingleElement.contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext)
				.steps.assertSingleElement.assertInstanceOf(ExpressionReturnTestStep)
				.returnExpression.assertInstanceOf(JsonNumber).value.assertEquals('42')
	}
	
	@Test
	def void parseMacroCallWithAmlElementParameter() {
		// given
		val input = '''
			package com.example

			# TestThatUsesMacroWithReturnValue

			* Test step
			Macro: MyMacroCollection
			- macro using <Input>
		'''

		// when
		val model = parseTcl(input).assertNoSyntaxErrors

		// then
		model.test.steps.assertSingleElement.contexts.assertSingleElement.assertInstanceOf(MacroTestStepContext)
		.steps.assertSingleElement.assertInstanceOf(TestStep).contents => [
			restoreString.assertEquals('macro using <Input>')
			get(2).assertInstanceOf(StepContentElement)
		]
	}
	
	@Test
	def void parseMacroDefinitionWithAmlElementParameter() {
		// given
		val input = '''
			package com.example

			# MyMacroCollection

			## MacroStartWith
			template = "start with" ${startparam} "in" ${field}
			Component: MyComponent
			- put @startparam into <@field>
		'''

		// when
		val model = parseTcl(input).assertNoSyntaxErrors

		// then
		model.macroCollection.macros.assertSingleElement => [
			template.contents => [
				get(0).assertInstanceOf(TemplateText)
				get(1).assertInstanceOf(TemplateVariable)
				get(2).assertInstanceOf(TemplateText)
				get(3).assertInstanceOf(TemplateVariable)
			]
			contexts.assertSingleElement.assertInstanceOf(ComponentTestStepContext)
				.steps.assertSingleElement.assertInstanceOf(TestStep)
				.contents.restoreString.assertEquals('put @startparam into <@field>')
		]
	}

	@Test
	def void parseSetup() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Setup:
				Component: Demo
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.setup.assertSingleElement.contexts.assertSingleElement
	}

	@Test
	def void parseCleanup() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Cleanup:
				Component: Demo
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.cleanup.assertSingleElement.contexts.assertSingleElement
	}

	@Test
	def void parseSetupAndCleanupBeforeSpecificationSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Setup:
				Component: MySetupComponent
			
			Cleanup:
				Component: MyCleanupComponent
			
			* step1
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.setup.assertNotNull
		test.cleanup.assertNotNull
		test.steps.assertSingleElement
	}

	@Test
	def void parseSetupAndCleanupAfterSpecificationSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			* step1
			
			Cleanup:
				Component: MyCleanupComponent
			
			Setup:
				Component: MySetupComponent
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.setup.assertNotNull
		test.cleanup.assertNotNull
		test.steps.assertSingleElement
	}
	
	@Test
	def void parseDataBeforeSpecificationSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
			Component: MyComponent
			- data = load my data
			
			* step1
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.data.assertSingleElement => [
			parameters.assertSize(3)
			parameters.assertExists[name.equals('firstName')]
			parameters.assertExists[name.equals('lastName')]
			parameters.assertExists[name.equals('age')]
		]
		test.steps.assertSingleElement
	}

	@Test
	def void parseDataAfterSpecificationSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			* step1
			
			Data: firstName, lastName, age
			Component: MyComponent
			- data = load my data
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.data.assertSingleElement => [
			parameters.assertSize(3)
			parameters.assertExists[name.equals('firstName')]
			parameters.assertExists[name.equals('lastName')]
			parameters.assertExists[name.equals('age')]
		]
		test.steps.assertSingleElement
	}
	
	@Test
	def void parseDataWithInitializationContext() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
				Component: MyDataInitializationComponent
				- myTestData = init test data
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.data.assertSingleElement => [
			parameters.assertSize(3)
			parameters.assertExists[name.equals('firstName')]
			parameters.assertExists[name.equals('lastName')]
			parameters.assertExists[name.equals('age')]
			context.assertInstanceOf(ComponentTestStepContext) => [
				component.assertNotNull
				steps.assertSingleElement.assertInstanceOf(TestStep) => [
					contents.restoreString.assertEquals('init test data')
				]
			]
		]
	}
	
	@Test
	def void parseDataWithoutTestParameters() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data:
				Component: MyDataInitializationComponent
				- myTestData = init test data
		'''

		// when
		val test = parseTcl(input).test

		// then
		test.assertNoSyntaxErrors
		test.data.assertSingleElement => [
			parameters.assertEmpty
			context => [
				assertInstanceOf(ComponentTestStepContext) => [
					component.assertNotNull
					steps.assertSingleElement.assertInstanceOf(TestStep) => [
						contents.restoreString.assertEquals('init test data')
					]
				]
			]
		]
	}

	@Test
	def void doesNotParseDataWithMacroContext() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
				Macro: MyMacroCollection
		'''

		// when
		val tclModel = parseTcl(input)

		// then
		tclModel.syntaxErrors.assertSingleElement.message.assertEquals('''
		The data block cannot have a macro test step context.
		E.g. replace the macro context with a component context like "Component: MyComponent".'''.toString)
	}
	
	@Test
	def void doesNotParseTestStepContextWithoutSpecificationStep() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Component: MyDataInitializationComponent
			- myTestData = init test data
		'''

		// when
		val tclModel = input.parseTcl('Test.tcl')

		// then
		tclModel.syntaxErrors.map[message].assertExistsEqual('''
			Insert a test description before the actual test context.
			E.g. "* This test will check that the answer will be 42"
		''')
	}
	
	@Test
	def void doesNotParseDataWithMultipleContexts() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
				Component: MyDataInitializationComponent
				- myTestData = init test data
				Component: MyOtherComponent
				- anotherStep
		'''

		// when
		val tclModel = parseTcl(input)

		// then
		tclModel.syntaxErrors.map[message].assertExistsEqual('The data block cannot have more than one test step context.')
	}
	
	@Test
	def void doesNotParseDataWithNoContext() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
		'''

		// when
		val tclModel = parseTcl(input)

		// then
		tclModel.syntaxErrors.map[message].assertExistsEqual('''
			The data block must have a component test step context.
			E.g. add "Component: MyComponent" after the data block line.
		''')
	}
	
	@Test
	def void doesNotParseDataWithMultipleTestSteps() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
				Component: MyDataInitializationComponent
				- myTestData = init test data
				- someOtherData = do something else
		'''

		// when
		val tclModel = parseTcl(input)

		// then
		tclModel.syntaxErrors.map[message].assertExistsEqual('The data block cannot have more than one test step.')
	}
	
	@Test
	def void doesNotParseDataWitTestStepWithoutAssignment() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			Data: firstName, lastName, age
				Component: MyDataInitializationComponent
				- init test data but not assigning it to anything
		'''

		// when
		val tclModel = parseTcl(input)

		// then
		tclModel.syntaxErrors.map[message].assertExistsEqual('''
		The data initialization step must be an assignment.
		E.g. prefix the step with "- myVar = ".''')
	}
	
	@Test
	def void parsesTestStepWithMultilineString() {
		// given
		val input = '''
			package com.example
			
			# Test
			
			* spec step
			Component: MyDataInitializationComponent
			- myTestData = step with "normal string" and "a string
			  spanning multiple
			  lines!"
		'''

		// when
		val tclModel = input.parseTcl('Test.tcl')

		// then
		tclModel.assertNoSyntaxErrors.test
			.steps.assertSingleElement
			.contexts.assertSingleElement
			.steps.assertSingleElement.assertInstanceOf(TestStepWithAssignment)
			.contents.restoreString.equals('''
			myTestData = step with "normal string" and "a string
			  spanning multiple
			  lines!"''')
	}
	
	private def <T extends EObject> syntaxErrors(T it) {
		return (eResource as XtextResource).parseResult.syntaxErrors.map[syntaxErrorMessage]
	}
	
	private def <T> void assertExistsEqual(Iterable<T> collection, T element) {
		collection.assertExists(
			[it === null && element === null || it !== null && equals(element)],
			'''Expected to find element equal to "«element»" in «collection».'''
		)
	}

}
