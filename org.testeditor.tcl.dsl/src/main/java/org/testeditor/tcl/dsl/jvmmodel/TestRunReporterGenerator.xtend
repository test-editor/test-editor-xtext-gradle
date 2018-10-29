package org.testeditor.tcl.dsl.jvmmodel

import java.util.List
import java.util.Optional
import javax.inject.Inject
import org.apache.commons.lang3.StringEscapeUtils
import org.apache.commons.lang3.StringUtils
import org.eclipse.xtext.common.types.JvmType
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.slf4j.LoggerFactory
import org.testeditor.fixture.core.MaskingString
import org.testeditor.fixture.core.TestRunReporter.Action
import org.testeditor.fixture.core.TestRunReporter.SemanticUnit
import org.testeditor.fixture.core.TestRunReporter.Status
import org.testeditor.tcl.StepContentElement
import org.testeditor.tcl.VariableReference
import org.testeditor.tcl.VariableReferencePathAccess
import org.testeditor.tcl.util.TclModelUtil

import static extension org.apache.commons.lang3.StringEscapeUtils.escapeJava

class TestRunReporterGenerator {

	@Inject TclExpressionBuilder expressionBuilder
	@Inject TclGeneratorConfig generatorConfig
	@Inject TclExpressionTypeComputer typeComputer
	@Inject extension TclModelUtil

	static val logger = LoggerFactory.getLogger(TestRunReporterGenerator)

	private def String getLocationInfo(StepContentElement stepElement) {
		val element = stepElement.componentElement
		val nodeModel = NodeModelUtils.findActualNodeFor(element)
		return '''«element.eResource.URI»«if (nodeModel !== null) ':' + nodeModel.startLine»''' // node model may be absent in some test
	}


	def List<Object> buildReporterCall(JvmType type, SemanticUnit unit, Action action, String message, String id, Status status,
		String reporterInstanceVariableName, List<VariableReference> variables, List<StepContentElement> amlElements, JvmTypeReference stringTypeReference) {
		val amlElementsList = if (amlElements !== null) {
			amlElements.filterNull.map[
				val element = componentElement
				val locator = element.locator.escapeJava
				val locatorStrategy = element.locatorStrategy?.qualifiedName?.escapeJava
				val locationInfo = getLocationInfo.escapeJava
				'''"<«element.name»>", "Locator: «locator»«if (locatorStrategy !== null)', Strategy: '+locatorStrategy» in «locationInfo»"'''
			].join(', ')
		} else {
			''
		}
		val variablesValuesList = if (variables !== null) {
				try {
					variables.filterNull.map [
						val varType = typeComputer.determineType(variable, Optional.empty)?.qualifiedName
						val maskingType = MaskingString.name

						'''"«if (it instanceof VariableReferencePathAccess) {
							StringEscapeUtils.escapeJava(restoreString)
						}else{
							variable.name
						}»", «if (maskingType.equals(varType)) {
							'"*****"'
						} else {
							expressionBuilder.buildReadExpression(it, stringTypeReference)
						}»'''
					].filterNull.join(', ')
				} catch (RuntimeException e) {
					logger.warn('error during generation of parameter passing for reporting', e)
					''
				}
			} else {
				''
			}

		val escapedMessage = StringEscapeUtils.escapeJava(message.trim)

		if (type === null) {
			logger.error('''typeRef='SemanticUnit' could not be resolved. This usually is a classpath problem (e.g. core-fixture unknown).''')
			return #['''
				// TODO: typeRef='SemanticUnit' could not be resolved.
			'''.toString]
		} else {
			return #['''

			«generateCommentPrefix»«initIdVar(action, id)»«reporterInstanceVariableName».«action.toString.toLowerCase»('''.toString, type,
				'''.«unit.name», "«escapedMessage»", «id», TestRunReporter.Status.«status.name», variables(«#[variablesValuesList,amlElementsList].filter[length>0].join(', ')»));'''.toString.replaceAll('" *\\+ *"',
					'')];
		}
	}

	private def String initIdVar(Action action, String idVar) {
		if (Action.ENTER.equals(action)) {
			'''String «idVar»=newVarId(); '''
		}
	}

	private def String generateCommentPrefix() {
		val prefix = generatorConfig.reporterCallCommentPrefixChar
		if (prefix !== null) {
			return '''/*«StringUtils.repeat(prefix, generatorConfig.reporterCallCommentPrefixCount)»*/ '''
		} else {
			return ''
		}
	}

}
