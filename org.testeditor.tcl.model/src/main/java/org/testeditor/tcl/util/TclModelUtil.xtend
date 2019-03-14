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
package org.testeditor.tcl.util

import java.util.HashSet
import java.util.LinkedHashMap
import java.util.Set
import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.util.OnChangeEvictingCache
import org.testeditor.aml.ComponentElement
import org.testeditor.aml.InteractionType
import org.testeditor.aml.ModelUtil
import org.testeditor.aml.Template
import org.testeditor.aml.TemplateContainer
import org.testeditor.aml.TemplateContent
import org.testeditor.aml.TemplateVariable
import org.testeditor.dsl.common.util.CollectionUtils
import org.testeditor.fixture.core.FixtureException
import org.testeditor.tcl.AbstractTestStep
import org.testeditor.tcl.AccessPathElement
import org.testeditor.tcl.ArrayPathElement
import org.testeditor.tcl.AssertionTestStep
import org.testeditor.tcl.AssignmentThroughPath
import org.testeditor.tcl.Comparison
import org.testeditor.tcl.ComponentTestStepContext
import org.testeditor.tcl.EnvironmentVariable
import org.testeditor.tcl.Expression
import org.testeditor.tcl.ExpressionReturnTestStep
import org.testeditor.tcl.KeyPathElement
import org.testeditor.tcl.Macro
import org.testeditor.tcl.MacroCollection
import org.testeditor.tcl.MacroTestStepContext
import org.testeditor.tcl.SpecificationStepImplementation
import org.testeditor.tcl.StepContentElement
import org.testeditor.tcl.StepContentElementReference
import org.testeditor.tcl.TclModel
import org.testeditor.tcl.TestCase
import org.testeditor.tcl.TestConfiguration
import org.testeditor.tcl.TestStep
import org.testeditor.tcl.TestStepContext
import org.testeditor.tcl.VariableReference
import org.testeditor.tcl.VariableReferencePathAccess
import org.testeditor.tsl.SpecificationStep
import org.testeditor.tsl.StepContent
import org.testeditor.tsl.StepContentText
import org.testeditor.tsl.StepContentValue
import org.testeditor.tsl.StepContentVariable
import org.testeditor.tsl.util.TslModelUtil

import static extension org.testeditor.tcl.util.MacroSignature.*

@Singleton
class TclModelUtil extends TslModelUtil {
	
	@Inject public extension ModelUtil amlModelUtil
	@Inject extension CollectionUtils
	@Inject OnChangeEvictingCache cache
	// Wrapper class around a test step to serve as cache key for macro lookup.
	// Since the cache adapter is resource-global, putting in TestStep objects
	// as keys might lead to collisions.
	@Data static class MacroCall {
		val TestStep step
	}

	/**
	 * Gets the name of the included element. Order of this operation:
	 * <ol>
	 * 	<li>Return the name of the {@link TestCase} if set</li>
	 * 	<li>Return the name of the {@link TestConfiguration} if set</li>
	 * 	<li>Return the name of the {@link MacroCollection} if set</li>
	 * 
	 * </ol>
	 */
	def String getName(TclModel model) {
		return model.test?.name ?: model.config?.name ?: model.macroCollection?.name
	}

	def String restoreString(VariableReferencePathAccess varPathAccess) {
		return '''«varPathAccess.variable.name»«varPathAccess.path.map[restoreString].join»'''
	}
	
	def String restoreString(AccessPathElement pathElement) {
		switch pathElement {
			ArrayPathElement: return '''[«pathElement.number»]'''
			KeyPathElement: return '''."«pathElement.key»"'''
			default: throw new RuntimeException('''Unknown path element type = '«pathElement.class»'.''')
		}
	}

	override String restoreString(Iterable<StepContent> contents) {
		return contents.map [
			switch (it) {
				StepContentVariable: '''"«value»"'''
				StepContentElement: '''<«value»>'''
				VariableReferencePathAccess: '''@«restoreString»'''
				VariableReference: if (it instanceof StepContentElementReference) {
					'''<@«variable?.name»>'''} else {
					'''@«variable?.name»''' }
				StepContentValue:
					value
				default:
					throw new IllegalArgumentException("Unhandled content: " + it)
			}
		].join(' ')
	}

	def Macro findMacro(TestStep step) {
		val context = step.macroContext
		if (context !== null && !context.eIsProxy) {
			return findMacroDefinition(step, step.macroContext)
		}
		return null
	}

	def Macro findMacroDefinition(TestStep macroCallStep, MacroTestStepContext macroCallSite) {
		return cache.get(new MacroCall(macroCallStep), macroCallSite.eResource)[
			val callSignature = macroCallStep.signature
			return macroCallSite.macroCollection?.macros?.findFirst[macro|
				val macroSignature = macro.signature[isAmlElementVariable(macro)]
				macroSignature.matches(callSignature)
			]
		]
	}

	def Expression getReturn(Macro macro) {
		return (macro.contexts?.last?.steps?.last as ExpressionReturnTestStep).returnExpression
	}
	
	def boolean hasReturn(Macro macro) {
		return macro.contexts?.last?.steps?.last instanceof ExpressionReturnTestStep
	}
	
	def TemplateContainer getTemplateContainer(TestStep step) {
		if (step.hasComponentContext) {
			return step.interaction
		}
		if (step.hasMacroContext) {
			return step.findMacro
		}
	}
	
	def InteractionType getInteraction(TestStep step) {
		// TODO this should be solved by using an adapter (so that we don't need to recalculate it over and over again)
		val component = step.componentContext?.component
		if (component !== null && !component.eIsProxy) {
			val allElementInteractions = component.elements.map[type.interactionTypes].flatten.filterNull
			val interactionTypes = component.type.interactionTypes + allElementInteractions
			val normalizedTestStep = step.normalize
			return interactionTypes.findFirst[template.normalize == normalizedTestStep]
		}
		return null
	}

	def String normalize(TestStep step) {
		val normalizedStepContent = step.contents.map [
			switch (it) {
				StepContentElement | StepContentElementReference: '<>'
				StepContentVariable: '""'
				VariableReference: '""'
				StepContentValue: value.trim
				default: throw new IllegalArgumentException("Unhandled content: " + it)
			}
		].join(' ').removeWhitespaceBeforePunctuation
		return normalizedStepContent
	}
	
	def String normalize(Macro macro, TemplateContent content) {
		switch (content) {
			TemplateVariable case content.isAmlElementVariable(macro): '<>'
			default: content.normalize
		}
	}

	/**
	 * Maps the non-text contents of a step to the variables used in the passed template.
	 * The result is ordered by appearance in the {@link TestStep}.
	 */
	def LinkedHashMap<StepContent, TemplateVariable> getStepContentToTemplateVariablesMapping(TestStep step, Template template) {
		val stepContentElements = step.contents.filter[!(it instanceof StepContentText)]
		val templateVariables = template.contents.filter(TemplateVariable)
		if (stepContentElements.size !== templateVariables.size) {
			val message = '''
				Variables for '«step.contents.restoreString»' did not match the parameters of template '«template.normalize»' (normalized).
			'''
			throw new IllegalArgumentException(message)
		}
		val map = newLinkedHashMap
		for (var i = 0; i < templateVariables.size; i++) {
			map.put(stepContentElements.get(i), templateVariables.get(i))
		}
		return map
	}
	
	def ComponentElement getComponentElement(TestStep testStep) {
		val contentElement = testStep.contents.filter(StepContentElement).head
		if (contentElement !== null) {
			val component = testStep.componentContext?.component
			return component?.elements?.findFirst[name == contentElement.value]
		}
		return null
	}

	def ComponentElement getComponentElement(StepContentElement contentElement) {
		val containingTestStep = EcoreUtil2.getContainerOfType(contentElement, TestStep)
		return contentElement.getComponentElement(containingTestStep)
	}
	
	def ComponentElement getComponentElement(StepContentElement contentElement, TestStep containingTestStep) {
		return getComponentElement(contentElement.value, containingTestStep)
	}
	
	def Iterable<ComponentElement> getAllComponentElements(StepContentElementReference contentElementRef) {
		val containingTestStep = EcoreUtil2.getContainerOfType(contentElementRef, TestStep)
		return contentElementRef.getAllComponentElements(containingTestStep)
	}
	
	def Iterable<ComponentElement> getAllComponentElements(StepContentElementReference contentElementRef, TestStep containingTestStep) {
		return containingTestStep?.componentContext?.component?.elements
	}
	
	def ComponentElement getComponentElement(String componentElementName, TestStep containingTestStep) {
		if (containingTestStep !== null) {
			val component = containingTestStep.componentContext?.component
			return component?.elements?.findFirst[name == componentElementName]
		}
		return null
	}
	
	def Template getMacroTemplate(StepContentElement contentElement) {
		val containingTestStep = EcoreUtil2.getContainerOfType(contentElement, TestStep)
		if (containingTestStep !== null) {
			val macro = containingTestStep.findMacroDefinition(containingTestStep.macroContext)
			return macro?.template
		}
		return null
	}
	
	def boolean hasComponentContext(StepContentElement stepContentElement) {
		return EcoreUtil2.getContainerOfType(stepContentElement, ComponentTestStepContext) !== null
	}

	def boolean hasComponentContext(TestStep step) {
		return step.componentContext !== null
	}
	
	def TestStepContext getTestStepContext(EObject eObject) {
		return if (eObject instanceof TestStepContext) {
			eObject
		} else {
			EcoreUtil2.getContainerOfType(eObject, TestStepContext)
		}
	}

	def ComponentTestStepContext getComponentContext(TestStep step) {
		return EcoreUtil2.getContainerOfType(step, ComponentTestStepContext)
	}

	def boolean hasMacroContext(AbstractTestStep step) {
		return step.macroContext !== null
	}

	def MacroTestStepContext getMacroContext(AbstractTestStep step) {
		return EcoreUtil2.getContainerOfType(step, MacroTestStepContext)
	}
	
	def boolean isPartOfMacroDefinition(ExpressionReturnTestStep step) {
		return step.enclosingMacroDefinition !== null
	}
	
	def Macro getEnclosingMacroDefinition(ExpressionReturnTestStep step) {
		return EcoreUtil2.getContainerOfType(step, Macro)
	}

	def Set<TemplateVariable> getEnclosingMacroParameters(EObject object) {
		val container = EcoreUtil2.getContainerOfType(object, Macro)
		if (container !== null) {
			return container.template.referenceableVariables
		}
		return #{}
	}
	
	/** 
	 * get all variables, variable references and elements that are used as parameters in this test step
	 */
	def Iterable<StepContent> getStepContentVariables(TestStep step) {
		return step.contents.filter[!(it instanceof StepContentText)]
	}

	def SpecificationStep getSpecificationStep(SpecificationStepImplementation stepImplementation) {
		val tslModel = stepImplementation.test.specification
		if (tslModel !== null) {
			return tslModel.steps.findFirst[matches(stepImplementation)]
		}
		return null
	}

	def Iterable<SpecificationStep> getMissingTestSteps(TestCase testCase) {
		val specSteps = testCase.specification?.steps
		val steps = testCase.steps
		if (specSteps === null) {
			return emptyList
		}
		if (steps === null) {
			return specSteps.toList
		}
		return specSteps.filter [
			val specStepContentsString = contents.restoreString
			return steps.forall[contents.restoreString != specStepContentsString]
		]
	}

	def Iterable<EnvironmentVariable> getEnvParams(EObject object) {
		val root = EcoreUtil2.getContainerOfType(object, TclModel)
		if (root !== null && root.environmentVariables !== null) {
			return root.environmentVariables
		}
		return #{}
	}

	/**
	 * does the given context make use of (one of the) variables passed via variable reference?
	 */
	def dispatch boolean makesUseOfVariablesViaReference(TestStepContext context, Set<String> variables) {
		return context.steps.exists [
			switch (it) {
				TestStep: contents.exists[makesUseOfVariablesViaReference(variables)]
				AssertionTestStep: assertExpression.makesUseOfVariablesViaReference(variables)
				AssignmentThroughPath: expression.makesUseOfVariablesViaReference(variables)
				ExpressionReturnTestStep: returnExpression.makesUseOfVariablesViaReference(variables)
				default: throw new RuntimeException('''Unknown TestStep type='«class.canonicalName»'.''')
			}
		]
	}

	def dispatch boolean makesUseOfVariablesViaReference(StepContent stepContent, Set<String> variables) {
		if (stepContent instanceof VariableReference) {
			return variables.contains(stepContent.variable.name)
		}
		return false
	}

	def dispatch boolean makesUseOfVariablesViaReference(Expression expression, Set<String> variables) {
		if( expression instanceof VariableReference) {
			return variables.contains(expression.variable.name)
		}
		return expression.eAllContents.filter(VariableReference).exists [
			variables.contains(variable.name)
		]
	}

	/**
	 * unwrap nested expressions hidden within degenerated comparison, in which only the left part is given and no comparator is present
	 */
	def Expression getActualMostSpecific(Expression expression) {
		if (expression instanceof Comparison) {
			if (expression.comparator === null) {
				return expression.left.actualMostSpecific
			}
		}
		return expression
	}

	/**
	 * Get the template variable of the interaction that is the corresponding parameter for this step content,
	 * given that the step content is part of a fixture call (interaction).
	 * 
	 * e.g. useful in combination with {@link SimpleTypeComputer#getVariablesWithTypes}
	 */
	def TemplateVariable getTemplateParameterForCallingStepContent(StepContent stepContent) {
		val testStep = EcoreUtil2.getContainerOfType(stepContent, TestStep)
		val callParameterIndex = testStep.stepContentVariables.indexOfFirst(stepContent)
		val templateContainer = testStep.templateContainer
		val templateParameters = templateContainer?.template?.contents?.filter(TemplateVariable)
		if (templateContainer !== null //
		&& templateParameters !== null //
		&& templateParameters.length > callParameterIndex) {
			return templateParameters.drop(callParameterIndex).head
		}
		return null
	}

	def dispatch boolean throwsFixtureException(Expression expression) {
		// expressions may not throw FixtureExceptions, yet!
		return false
	}

	def dispatch boolean throwsFixtureException(AssignmentThroughPath assignmentThroughPath) {
		return assignmentThroughPath.expression.throwsFixtureException
	}

	def dispatch boolean throwsFixtureException(AssertionTestStep assertionTestStep) {
		return assertionTestStep.assertExpression.throwsFixtureException
	}

	def dispatch boolean throwsFixtureException(TestStep testStep) {
		val container = testStep.templateContainer
		switch (container) {
			InteractionType: return container.defaultMethod?.operation?.exceptions.exists[FixtureException.name.equals(qualifiedName)]
			Macro: return container.contexts.throwsFixtureException
			default: return false
		}
	}
	

	def dispatch boolean throwsFixtureException(ExpressionReturnTestStep testStep) {
		return throwsFixtureException(testStep.returnExpression)
	}

	def dispatch boolean throwsFixtureException(Iterable<TestStepContext> contexts) {
		return contexts.exists[steps.exists[throwsFixtureException]]
	}
	
	def Iterable<VariableOccurence> getUsagesOf(Macro macro, TemplateVariable variable) {
		return macro.contexts.flatMap[context|
			context.steps.filter(TestStep).flatMap[step|
				step.contents.filter(VariableReference).indexed
				.filter[value.variable == variable].map[
					new VariableOccurence(context, step, value, key)
			]]]
	}

	def Set<ComponentElement> getValidElementsFor(Macro macro, TemplateVariable variable) {
		return macro.contexts.getValidElementsFor(variable)
	}

	def Set<ComponentElement> getValidElementsFor(Iterable<TestStepContext> contexts, TemplateVariable variable) {
		return contexts.flatMap[context|
			context.steps.filter(TestStep).flatMap[step|
				step.contents.filter(VariableReference).indexed.filter[value.variable == variable]
				.map[context.getValidElementsFor(step, key)]
			]
		].reduce[setA, setB| (new HashSet(setA) as Set<ComponentElement>) => [retainAll(setB)]]
	}

	def Set<ComponentElement> getValidElements(VariableOccurence it) {
		return getValidElementsFor(context, step, parameterPosition)
	}

	def Set<ComponentElement> getValidElementsFor(TestStepContext context, TestStep step, int parameterPosition) {
		return switch (context) {
			ComponentTestStepContext: {
				val interaction = step.interaction
				context.component.elements.filter[componentElementInteractionTypes.contains(interaction)].toSet
			}
			MacroTestStepContext: {
				val calledMacro = step.findMacroDefinition(context)
				val param = calledMacro.template.contents.filter(TemplateVariable).toList.get(parameterPosition)
				calledMacro.getValidElementsFor(param)
			}
			default: #{}
		}
	}

	def Iterable<TemplateVariable> getAmlElementParameters(Macro macro) {
		return macro.template.contents.filter(TemplateVariable).filter[isAmlElementVariable(macro)]
	}

	def boolean isAmlElementVariable(TemplateVariable variable, Macro macro) {
		return	variable.isUsedAsElementInComponentInteractionCall(macro) || 
				variable.isUsedAsElementInMacroCall(macro)
	}

	private def boolean isUsedAsElementInComponentInteractionCall(TemplateVariable variable, Macro macro) {
		return macro.contexts.filter(ComponentTestStepContext)
			.exists[steps.filter(TestStep)
				.exists[contents.filter(StepContentElementReference)
					.exists[it.variable == variable]
			]
		]
	}

	private def boolean isUsedAsElementInMacroCall(TemplateVariable variable, Macro macro) {
		return macro.contexts.filter(MacroTestStepContext)
			.exists[context| context.steps.filter(TestStep)
				.exists[step | step.contents.filter(VariableReference).indexed
					.exists[
						if (value.variable == variable) { 
							val calledMacro = step.findMacroDefinition(context)
							val passedParam = calledMacro.template.contents.filter(TemplateVariable).toList.get(key)
							passedParam.isAmlElementVariable(calledMacro)
						} else {
							false
						}
					]
				]
			]
	}
	
	@Data static class VariableOccurence {
		TestStepContext context
		TestStep step
		VariableReference reference
		int parameterPosition
	}
}
