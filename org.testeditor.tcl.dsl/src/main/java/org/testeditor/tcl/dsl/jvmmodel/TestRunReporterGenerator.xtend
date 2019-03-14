package org.testeditor.tcl.dsl.jvmmodel

import java.util.List
import java.util.Optional
import javax.inject.Inject
import org.apache.commons.lang3.StringEscapeUtils
import org.apache.commons.lang3.StringUtils
import org.eclipse.xtext.common.types.JvmType
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.generator.trace.AbstractTraceRegion
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
	@Inject JvmModelHelper modelHelper
	@Inject extension TclModelUtil

	static val logger = LoggerFactory.getLogger(TestRunReporterGenerator)

    static val RESOURCE_PREFIX = '/src/test/java/'

	private def String getLocationInfo(StepContentElement stepElement) {
		val element = stepElement.componentElement
		val nodeModel = NodeModelUtils.findActualNodeFor(element)
        val resourceURI = element.eResource.URI.toString
        val resourcePath = if (resourceURI.contains(RESOURCE_PREFIX)) {
            resourceURI.substring(resourceURI.indexOf(RESOURCE_PREFIX)+RESOURCE_PREFIX.length())
        } else {
            resourceURI
        }
		return '''«resourcePath»«if (nodeModel !== null) ':' + nodeModel.startLine»''' // node model may be absent in some test
	}


	def List<Object> buildReporterCall(JvmType type, SemanticUnit unit, Action action, String message, String id, String parentId, Status status,
		String reporterInstanceVariableName, AbstractTraceRegion traceRegion, List<VariableReference> variables, List<StepContentElement> amlElements, JvmTypeReference stringTypeReference) {
		val amlElementsList = if (amlElements !== null) {
			amlElements.filterNull.filter[hasComponentContext].map[
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
			
		val locationVarList = '''"@", "«modelHelper.toLocationString(traceRegion)»"'''

		val escapedMessage = StringEscapeUtils.escapeJava(message.trim)

		if (type === null) {
			logger.error('''typeRef='SemanticUnit' could not be resolved. This usually is a classpath problem (e.g. core-fixture unknown).''')
			return #['''
				// TODO: typeRef='SemanticUnit' could not be resolved.
			'''.toString]
		} else {
			return #['''

			«generateCommentPrefix»«initIdVar(action, id, parentId)»«reporterInstanceVariableName».«action.toString.toLowerCase»('''.toString, type,
				'''.«unit.name», "«escapedMessage»", «id», TestRunReporter.Status.«status.name», variables(«#[variablesValuesList,amlElementsList,locationVarList].filter[length>0].join(', ')»));'''.toString.replaceAll('" *\\+ *"',
					'')];
		}
	}

	private def String initIdVar(Action action, String idVar, String parentId) {
		if (Action.ENTER.equals(action)) {
			'''String «idVar»=nextSubId(«parentId»); '''
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
