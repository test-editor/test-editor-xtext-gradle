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
package org.testeditor.aml.dsl.tests.parser

import javax.inject.Inject
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.testeditor.aml.dsl.tests.AbstractAmlTest
import org.testeditor.dsl.common.testing.DslParseHelper

abstract class AbstractParserTest extends AbstractAmlTest {

	@Inject protected extension ValidationTestHelper
	@Inject protected extension DslParseHelper

}
