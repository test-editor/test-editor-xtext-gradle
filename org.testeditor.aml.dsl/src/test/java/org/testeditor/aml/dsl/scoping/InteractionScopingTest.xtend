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
package org.testeditor.aml.dsl.scoping

import javax.inject.Inject
import org.eclipse.xtext.diagnostics.Severity
import org.junit.Test
import org.testeditor.aml.ModelUtil
import org.testeditor.aml.TemplateVariable
import org.testeditor.aml.dsl.validation.AmlValidator
import org.testeditor.dsl.common.testing.DummyFixture

/**
 * Tests scoping for interactions / template variables.
 */
class InteractionScopingTest extends AbstractScopingTest {

	@Inject extension ModelUtil
	
	@Test
	def void testImportedInteractionScope() {
		// Given
		val file1 = '''
			package com.example
			
			interaction type Resize {
				template = "Resize" ${element} "to size" ${size}
			}
			
			component type Dialog {
				interactions = Resize
			}
		'''
		val file2 = '''
			package org.testeditor
			
			import com.example.*
			
			component MyDialog is Dialog {
				restrict Resize.size to ResizePercent
			}
			
			value-space ResizePercent = 10 .. 100
		'''

		// When
		val model1 = parseAml(file1)
		val model2 = parseAml(file2)

		// Then
		model1.assertNoErrors
		model2.assertNoErrors

		// Verfiy object identity		
		val dialog = model1.componentTypes.assertSingleElement
		val myDialog = model2.components.assertSingleElement
		myDialog.type.assertSame(dialog)

		val template = model1.interactionTypes.assertSingleElement.template
		val sizeVariable = template.referenceableVariables.assertSingleElement
		myDialog.valueSpaceAssignments.assertSingleElement => [
			variable.assertSame(sizeVariable)
		]
	}

	/**
	 * Test that a reference to a fixture method (annotated with @FixtureMethod)
	 * can be resolved properly.
	 */
	@Test
	def void testInteractionMethodReference() {
		// Given
		val file = resizeInteraction('someFixtureMethod')

		// When
		val model = parseAml(file)

		// Then
		model.assertNoErrors
		val interaction = model.interactionTypes.assertSingleElement
		interaction.defaultMethod.typeReference.qualifiedName.assertEquals(DummyFixture.name)
	}

	/**
	 * Test that a reference to a non-fixture method (not annotated with @FixtureMethod)
	 * cannot be resolved as it is not in scope. 
	 */
	@Test
	def void testInteractionInvalidMethodReference() {
		// Given
		val file = resizeInteraction('someUnrelatedMethod')

		// When
		val model = parseAml(file)

		// Then
		model.validate.assertSize(2) => [
			head => [
				severity.assertEquals(Severity.ERROR)
				message.assertEquals("someUnrelatedMethod cannot be resolved to an operation.")
			]
			last => [
				severity.assertEquals(Severity.WARNING)
				code.assertEquals(AmlValidator.METHOD_REFERENCE__EXCEPTION_MISSING)
			]
		]
	}

	@Test
	def void canParseInteractionMethodReferenceWithParentheses() {
		// Given
		val file = resizeInteraction('someFixtureMethod()')

		// When
		val model = parseAml(file)

		// Then
		model.assertNoErrors
	}

	@Test
	def void hasErrorWhenReferencedMethodDoesNotHaveParameter() {
		// Given
		val file = resizeInteraction('someFixtureMethod(size)')

		// When
		val model = parseAml(file)

		// Then
		val issue = model.validate.assertSingleElement
		issue => [
			severity.assertEquals(Severity.ERROR)
			message.assertEquals("Invalid parameter count.")
		]
	}

	@Test
	def void canParseInteractionWithParameterReference() {
		// Given
		val file = '''
			package «DummyFixture.package.name»
			
			interaction type start {
				template = "Starte Anwendung" ${path}
				method = DummyFixture.startApplication(path)
			}
		'''

		// When
		val model = parseAml(file)

		// Then
		model.assertNoErrors
		val interaction = model.interactionTypes.assertSingleElement
		val pathVariable = interaction.template.contents.filter(TemplateVariable).head.assertNotNull
		interaction.defaultMethod => [
			parameters.head.assertSame(pathVariable)
		]
	}

	@Test
	def void canParseWithElementParameterReference() {
		// Given
		val file = '''
			package «DummyFixture.package.name»
			
			interaction type set {
				template = "Set value" ${value} "on element" ${element}
				method = DummyFixture.setValue(element, value)
			}
		'''

		// When
		val model = parseAml(file)

		// Then
		model.assertNoErrors
		val interaction = model.interactionTypes.assertSingleElement
		val variables = interaction.template.contents.filter(TemplateVariable)
		interaction.defaultMethod => [
			parameters.assertSize(2)
			parameters.head.assertSame(variables.findFirst[name == 'element'])
			parameters.last.assertSame(variables.findFirst[name == 'value'])
		]
	}

	private def resizeInteraction(String operationRef) '''
		package «DummyFixture.package.name»
			
			interaction type Resize {
				template = "Resize" ${element} "to size" ${size}
				method = DummyFixture.«operationRef»
			}
	'''

}
