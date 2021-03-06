package org.testeditor.tcl.util

import java.util.Map
import java.util.Set
import javax.inject.Inject
import org.junit.Before
import org.junit.Test
import org.testeditor.aml.ModelUtil
import org.testeditor.aml.Template
import org.testeditor.aml.TemplateVariable
import org.testeditor.aml.dsl.AmlStandaloneSetup
import org.testeditor.aml.dsl.tests.AmlModelGenerator
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.tcl.AbstractTestStep
import org.testeditor.tcl.MacroTestStepContext
import org.testeditor.tcl.TestStep
import org.testeditor.tcl.VariableReference
import org.testeditor.tcl.dsl.services.TclGrammarAccess
import org.testeditor.tcl.dsl.tests.TclModelGenerator
import org.testeditor.tcl.dsl.tests.parser.AbstractParserTest
import org.testeditor.tsl.StepContentVariable

class TclModelUtilTest extends AbstractParserTest {

	@Inject var TclModelUtil tclModelUtil // class under test
	@Inject extension TclModelGenerator
	@Inject extension AmlModelGenerator

	@Inject ModelUtil modelUtil
	@Inject TclGrammarAccess grammarAccess

	@Before
	def void setup() {
		(new AmlStandaloneSetup).createInjectorAndDoEMFRegistration
	}

	@Test
	def void testRestoreString() {
		// given
		val testStep = parse('-  <hello>     world "ohoh"   @xyz', grammarAccess.testStepRule, TestStep)
		testStep.contents.get(3).assertInstanceOf(VariableReference)

		// when
		val result = tclModelUtil.restoreString(testStep.contents)

		// then
		result.assertMatches('<hello> world "ohoh" @') // empty variable reference name, since the reference is null
	}

	@Test
	def void restoreStringWithPunctuation() {
		// given
		val questionMark = parse('- Hello World?', grammarAccess.testStepRule, TestStep)
		val questionMarkAndWhitespace = parse('- Hello World  ?', grammarAccess.testStepRule, TestStep)
		val dot = parse('- Hello World  .', grammarAccess.testStepRule, TestStep)
		val dotAndWhitespace = parse('- Hello World.', grammarAccess.testStepRule, TestStep)

		// when, then
		tclModelUtil.restoreString(questionMark.contents).assertEquals('Hello World ?')
		tclModelUtil.restoreString(questionMarkAndWhitespace.contents).assertEquals('Hello World ?')
		tclModelUtil.restoreString(dot.contents).assertEquals('Hello World .')
		tclModelUtil.restoreString(dotAndWhitespace.contents).assertEquals('Hello World .')
	}

	@Test
	def void testFindMacroDefinition() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MacroStartWith
			template = "start with" ${startparam}
			Component: MyComponent
			- put @startparam into <other>
			
			## MacroUseWith
			template = "use macro with" ${useparam}
			Macro: MyMacroCollection
			- start with @useparam
		''')
		val macroCalled = tmlModel.macroCollection.macros.head
		val macroCall = tmlModel.macroCollection.macros.last
		val macroTestStepContext = macroCall.contexts.head as MacroTestStepContext

		// when
		val macro = tclModelUtil.findMacroDefinition(macroTestStepContext.steps.filter(TestStep).head, macroTestStepContext)

		// then
		macro.assertSame(macroCalled)
	}
	
	@Test
	def void testFindMacroDefinitionWithPunctuation() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## LoginAufJiraTestSeite
			template = "Browser starten und auf Seite" ${url} "navigieren."
			Component: GreetingApplication
			- Start application @url
			
			
			## MacroUse
			template = "Starten"
			Macro: MyMacroCollection
			- Browser starten und auf Seite "http://example.org" navigieren.
		''')
		val macroCalled = tmlModel.macroCollection.macros.head
		val macroCall = tmlModel.macroCollection.macros.last
		val macroTestStepContext = macroCall.contexts.head as MacroTestStepContext

		// when
		val macro = tclModelUtil.findMacroDefinition(macroTestStepContext.steps.filter(TestStep).head, macroTestStepContext)

		// then
		macro.assertSame(macroCalled)
	}
	
	@Test
	def void testFindMacroDefinitionWithAmlParameter() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Type @value into <@field>
		''', 'MyMacroCollection.tml')
		val tclModel = '''
			package com.example
			
			# Test
			
			* Some spec
			Macro: MyMacroCollection
			- enter "42" into <Input>
			- enter "42" into "Input"
		'''.toString.parseTcl('Test.tcl')
		
		val expectedMacro = tmlModel.macroCollection.macros.head
		val macroTestStepContext = tclModel.test.steps.head.contexts.head as MacroTestStepContext
		val macroCalls = macroTestStepContext.steps.filter(TestStep)

		// when
		val actuallyFoundMacros = macroCalls.map[
			tclModelUtil.findMacroDefinition(it, macroTestStepContext)]

		// then
		actuallyFoundMacros.head.assertSame(expectedMacro)
		actuallyFoundMacros.last.assertSame(expectedMacro)	// findMacroDefinition does not check if a parameter is an AML element, so normal quotes will match, too
															// TODO a separate validation should check that angle brackets are used for AML element parameters
	}
	
	@Test
	def void testMacroDefinitionHasReturn() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "call macro with return"
			Component: MyComponent
			- some step
			- return 42
		''')
		val macro = tmlModel.macroCollection.macros.head

		// when
		val actualResult = tclModelUtil.hasReturn(macro)

		// then
		actualResult.assertTrue
	}
	
	@Test
	def void testMacroDefinitionHasNoReturn() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "call macro with return"
			Component: MyComponent
			- some step
			- some other step
		''')
		val macro = tmlModel.macroCollection.macros.head

		// when
		val actualResult = tclModelUtil.hasReturn(macro)

		// then
		actualResult.assertFalse
	}
	
	@Test
	def void testEmptyMacroDefinitionHasNoReturn() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "call macro with return"
			Component: MyComponent
		''')
		val macro = tmlModel.macroCollection.macros.head

		// when
		val actualResult = tclModelUtil.hasReturn(macro)

		// then
		actualResult.assertFalse
	}
	
	@Test
	def void testIllegalMacroDefinitionHasNoReturn() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "call macro with return"
			Component: MyComponent
			- return 42
			- some step
		''')
		val macro = tmlModel.macroCollection.macros.head

		// when
		val actualResult = tclModelUtil.hasReturn(macro)

		// then
		actualResult.assertFalse
	}
	
	@Test
	def void testIllegalMacroDefinitionWithMultipleContextsHasNoReturn() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "call macro with return"
			Component: MyComponent
			- return 42
			Macro: SomeOtherMacro
			- some step
		''')
		val macro = tmlModel.macroCollection.macros.head

		// when
		val actualResult = tclModelUtil.hasReturn(macro)

		// then
		actualResult.assertFalse
	}
	
	@Test
	def void testGetSingleAmlElementParameter() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "use AMLElement " ${field}
			Component: MyComponent
			- put "42" into <@field>
		''')
		val macro = tmlModel.macroCollection.macros.head
		
		// when
		val actualResult = tclModelUtil.getAmlElementParameters(macro)
		
		// then
		actualResult.assertSingleElement => [
			name.assertEquals('field')
		]
	}

	@Test
	def void testGetOnlyAmlElementParameter() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: MyComponent
			- put @value into <@field>
		''')
		val macro = tmlModel.macroCollection.macros.head
		
		// when
		val actualResult = tclModelUtil.getAmlElementParameters(macro)
		
		// then
		actualResult.assertSingleElement => [
			name.assertEquals('field')
		]
	}
	
	@Test
	def void testGetAmlElementParameterRecursively() {
		// given
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: MyComponent
			- put @value into <@field>
			
			## MySecondMacro
			template "indirectly enter" ${value} "into" ${field}
			Macro: MyMacroCollection
			- enter @value into @field
		''')
		val macro = tmlModel.macroCollection.macros.last
		
		// when
		val actualResult = tclModelUtil.getAmlElementParameters(macro)
		
		// then
		actualResult.assertSingleElement => [
			name.assertEquals('field')
		]
	}
	
	@Test
	def void testGetValidAmlElementsForMacroParameter() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Set value of <@field> to @value
		''')
		val macro = tmlModel.macroCollection.macros.head
		
		// when
		val actualResult = tclModelUtil.getValidElementsFor(macro, tclModelUtil.getAmlElementParameters(macro).assertSingleElement)
		
		// then
		actualResult.assertSingleElement => [
			name.assertEquals('Input')
		]
	}
	
	@Test
	def void testGetMultipleValidAmlElementsForMacroParameter() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl('''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "check visibility of" ${field}
			Component: GreetingApplication
			- Is <@field> visible?
		''')
		val macro = tmlModel.macroCollection.macros.head
		
		// when
		val actualResult = tclModelUtil.getValidElementsFor(macro, tclModelUtil.getAmlElementParameters(macro).assertSingleElement)
		
		// then
		actualResult.assertExists[name.equals('Input')]
		actualResult.assertExists[name.equals('bar')]
		actualResult.assertExists[name.equals('Ok')]
		actualResult.assertSize(3)
	}
	
	@Test
	def void testGetValidAmlElementsForMacroParameterRecursively() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Set value of <@field> to @value
			
			## MySecondMacro
			template "indirectly enter" ${value} "into" ${field}
			Macro: MyMacroCollection
			- enter @value into <@field>
		''')
		val macro = tmlModel.macroCollection.macros.last
		
		// when
		val actualResult = tclModelUtil.getValidElementsFor(macro, tclModelUtil.getAmlElementParameters(macro).assertSingleElement)
		
		// then
		actualResult.assertSingleElement => [
			name.assertEquals('Input')
		]
	}

	/**
	 * AML element parameter is used in more than one interaction, but
	 * inconsistently, i.e. without any intersection of valid elements.
	 * The overall result of valid elements should therefore be empty.
	 */
	@Test
	def void testGetValidAmlElementsForMacroParameterInconsistentUsages() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Type "Hello, World!" into <@field>
			- Click on <@field>
		''')
		val macro = tmlModel.macroCollection.macros.head
		
		// when
		val actualResult = tclModelUtil.getValidElementsFor(macro, tclModelUtil.getAmlElementParameters(macro).assertSingleElement)
		
		// then
		actualResult.assertEmpty
	}
	
	
	/**
	 * AML element parameter is used in more than one interaction.
	 * The sets of valid elements for each usage should be intersected to yield
	 * the overall result.
	 */
	@Test
	def void testGetValidAmlElementsForMacroParameterOverlappingUsages() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Is <@field> visible?
			- Read value from <@field>
			- Is <@field> visible?

		''')
		val macro = tmlModel.macroCollection.macros.head
		
		// when
		val actualResult = tclModelUtil.getValidElementsFor(macro, tclModelUtil.getAmlElementParameters(macro).assertSingleElement)
		
		// then
		actualResult.assertExists[name.equals('Input')]
		actualResult.assertExists[name.equals('bar')]
		actualResult.assertSize(2)
	}

	@Test
	def void testNormalizeTemplate() {
		// given
		val template = parse('''
		"start with" ${somevar} "and more" ${othervar} "?"''', grammarAccess.templateRule, Template)

		// when
		val normalizedTemplate = modelUtil.normalize(template)

		// then
		normalizedTemplate.assertEquals('start with "" and more ""?')
	}
	
	@Test
	def void testNormalizeAmlParameterInTemplate() {
		// given
		DummyFixture.amlModel.parseAml
		val tmlModel = parseTcl( '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Type @value into <@field>
		''')
		val macro = tmlModel.macroCollection.macros.head
		val templateVariables = macro.template.contents.filter(TemplateVariable)
		
		// when
		val normalizedVariables = templateVariables.map[tclModelUtil.normalize(macro, it)]

		// then
		normalizedVariables.head.assertEquals('""')
		normalizedVariables.last.assertEquals('<>')
	}

	@Test
	def void testNormalizeTestStepWithElementVar() {
		// given
		val testStep = parse('''
		- enter "Hello, World!" into <@field>''', grammarAccess.testStepRule, TestStep)

		// when
		val normalizedTestStep = tclModelUtil.normalize(testStep)

		// then
		normalizedTestStep.assertEquals('enter "" into <>')
	}
	
	@Test
	def void testNormalizeTestStep() {
		// given
		val testStep = parse('''
		- start with "some" and more @other ?''', grammarAccess.testStepRule, TestStep)

		// when
		val normalizedTestStep = tclModelUtil.normalize(testStep)

		// then
		normalizedTestStep.assertEquals('start with "" and more ""?')
	}

	@Test
	def void testStepContentToTemplateVariablesMapping() {
		// given
		val testStep = parse('''
		- start with "some" and more @other''', grammarAccess.testStepRule, TestStep)
		val template = parse('''
		"start with" ${somevar} "and more" ${othervar}''', grammarAccess.templateRule, Template)
		val someValue = testStep.contents.filter(StepContentVariable).head
		val otherRef = testStep.contents.filter(VariableReference).head
		val somevar = template.contents.get(1)
		val othervar = template.contents.get(3)

		// when
		val map = tclModelUtil.getStepContentToTemplateVariablesMapping(testStep, template)

		// then
		map.entrySet.assertSize(2)
		map.get(someValue).assertSame(somevar)
		map.get(otherRef).assertSame(othervar)
	}

	@Test
	def void testMakesUseOfVariablesViaReference_TemplateVariableInStep() {
		// given
		val variable = templateVariable("var") // a template var
		val step = testStep("some").withReferenceToVariable(variable) // a test step using that var
		// when, then
		// create some complete model (test case, ....) around the test step and check that it is actually using this var!
		testMakesUseOfVariablesViaReference_VariableInStep("var", step)
	}

	@Test
	def void testMakesUseOfVariablesViaReference_TemplateVariableInAssertion() {
		// given
		val variable = templateVariable("var") // a template var
		val step = assertionTestStep => [
			// an assertion using this var
			assertExpression = compareMatching(variableReference => [it.variable = variable], "compared-with")
		]

		// when, then
		// create some complete model (test case, ....) around the assertion step and check that it is actually using this var!
		testMakesUseOfVariablesViaReference_VariableInStep("var", step)
	}

	@Test
	def void testMakesUseOfVariablesViaReference_EnvironmentVariableInStep() {
		// given
		val variable = environmentVariablesPublic("var").head // an environment var
		val step = testStep("some").withReferenceToVariable(variable) // a test step using that var
		// when, then
		// create some complete model (test case, ....) around the test step and check that it is actually using this var!
		testMakesUseOfVariablesViaReference_VariableInStep("var", step)
	}

	@Test
	def void testMakesUseOfVariablesViaReference_EnvironmentVariableInAssertion() {
		// given
		val variable = environmentVariablesPublic("var").head // an environment var
		val step = assertionTestStep => [
			// an assertion using this var
			assertExpression = compareMatching(variableReference => [it.variable = variable], "compared-with")
		]

		// when, then
		// create some complete model (test case, ....) around the assertion step and check that it is actually using this var!
		testMakesUseOfVariablesViaReference_VariableInStep("var", step)
	}

	@Test
	def void testDetectionOfOneStepTransitivelyThrowingTheException() {
		// given
		DummyFixture.amlModel.parseAml
		val tclModel = '''
			package com.example
			
			# Test
			
			* Some spec
			Component: GreetingApplication
			- Stop application
		'''.toString.parseTcl('Test.tcl')
		tclModel.assertNoErrors

		// when
		val result = tclModelUtil.throwsFixtureException(tclModel.test.steps.head.contexts)

		// then
		result.assertTrue
	}

	@Test
	def void testDetectionOfNoStepTransitivelyThrowingTheException() {
		// given
		DummyFixture.amlModel.parseAml
		val tclModel = '''
			package com.example
			
			# Test
			
			* Some spec
			Component: GreetingApplication
			- Read value from <Input>
			- boolVal = Read bool from <Input>
			- Type boolean "true" input <Input>
		'''.toString.parseTcl('Test.tcl')
		tclModel.assertNoErrors

		// when
		val result = tclModelUtil.throwsFixtureException(tclModel.test.steps.head.contexts)

		// then
		result.assertFalse
	}

	@Test
	def void testDetectionWithinMacrosThrowingFixtureException() {
		// given
		DummyFixture.amlModel.parseAml
		'''
			package com.example
			
				# Macros
				
				## testMacro
				template = "testMacro"
				Component: GreetingApplication
				- Read value from <Input>
				- boolVal = Read bool from <Input>
				Macro: Macros
				- innerMacro
				
				## innerMacro
				template = "innerMacro"
				Component: GreetingApplication
				- Stop application
				- Type boolean "true" input <Input>
		'''.toString.parseTcl('Macros.tml')

		val tclModel = '''
			package com.example
			
			# Test
			
			* Some spec
			Macro: Macros
			- testMacro
		'''.toString.parseTcl('Test.tcl')
		tclModel.assertNoErrors

		// when
		val result = tclModelUtil.throwsFixtureException(tclModel.test.steps.head.contexts)

		// then
		result.assertTrue
	}

	@Test
	def void testDetectionWithinMacrosThrowingNoFixtureException() {
		// given
		DummyFixture.amlModel.parseAml
		'''
			package com.example
			
				# Macros
				
				## testMacro
				template = "testMacro"
				Component: GreetingApplication
				- Read value from <Input>
				- boolVal = Read bool from <Input>
				Macro: Macros
				- innerMacro
				
				## innerMacro
				template = "innerMacro"
				Component: GreetingApplication
				- Type boolean "true" input <Input>
		'''.toString.parseTcl('Macros.tml')

		val tclModel = '''
			package com.example
			
			# Test
			
			* Some spec
			Macro: Macros
			- testMacro
		'''.toString.parseTcl('Test.tcl')
		tclModel.assertNoErrors

		// when
		val result = tclModelUtil.throwsFixtureException(tclModel.test.steps.head.contexts)

		// then
		result.assertFalse
	}

	@Test
	def void testDetectForOneOfManyStepsTransitivelyThrowingFixtureException() {
		// given
		DummyFixture.amlModel.parseAml
		val tclModel = '''
			package com.example
			
			# Test
			
			* Some spec
			Component: GreetingApplication
			- Read value from <Input>
			- boolVal = Read bool from <Input>
			- Stop application
			- Type boolean "true" input <Input>
		'''.toString.parseTcl('Test.tcl')
		tclModel.assertNoErrors

		// when
		val result = tclModelUtil.throwsFixtureException(tclModel.test.steps.head.contexts)

		// then
		result.assertTrue
	}

	/**
	 * test that the step passed is identified correctly for using the variable.
	 * test also that this step is not identified to be using variables that differ from the one passed. 
	 */
	private def void testMakesUseOfVariablesViaReference_VariableInStep(String variableName, AbstractTestStep step) {
		val context = componentTestStepContext(null) => [
			steps += step
		]

		val nonMatchingVariableName1 = variableName + "A"
		val nonMatchingVariableName2 = "B" + variableName
		val expectations = #{
			#{variableName} -> true,
			#{nonMatchingVariableName1, variableName, nonMatchingVariableName2} -> true,
			#{} -> false,
			#{nonMatchingVariableName1, nonMatchingVariableName2} -> false
		}

		// when
		val results = newHashMap
		expectations.forEach[key, value|results.put(key, tclModelUtil.makesUseOfVariablesViaReference(context, key))]

		// then
		results.assertEquals(expectations)
	}

	private def <K, V> void assertEquals(Map<K, V> actualMap, Map<K, V> expectedMap) {
		assertEquals(actualMap.keySet, expectedMap.keySet, "key set differs")
		actualMap.forEach [ key, value |
			assertEquals(expectedMap.get(key), value, '''value of key='«key»' differ (expected='«expectedMap.get(key)»' != actual='«actualMap.get(key)»').''')
		]
	}

	private def <V> void assertEquals(Set<V> actualSet, Set<V> expectedSet, String message) {
		assertEquals(actualSet.size, expectedSet.size, 'set size differs: ' + message)
		actualSet.forEach [
			assertTrue(expectedSet.contains(it), '''expected set does not contain value='«it»': ''' + message)
		]
	}

}
